import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/app_setting.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Chuyển dữ liệu từ mô hình cũ (tuỳ chọn áp dụng theo thuộc tính, tồn kho
/// gắn linh kiện, shop dạng chuỗi) sang mô hình biến thể:
///
/// - Mỗi linh kiện có các [ComponentVariant] (linh kiện không thuộc tính => 1
///   biến thể mặc định). Biến thể được tạo từ tồn kho cũ + linh kiện trong dự
///   án; nếu chưa có gì thì tạo đủ tổ hợp (tối đa [maxGeneratedCombinations]).
/// - Tuỳ chọn mua hàng gắn với các biến thể khớp phạm vi áp dụng cũ.
/// - Tên shop dạng chuỗi => bảng [Shop].
/// - Linh kiện trong dự án trỏ thẳng tới biến thể.
///
/// An toàn khi chạy lại: chỉ xử lý linh kiện chưa có biến thể và dữ liệu cũ
/// còn sót.
class VariantMigration {
  static const settingKey = "schema_version";
  static const schemaVersion = 2;
  static const maxGeneratedCombinations = 30;

  final _db = ObjectboxService.instance;

  /// Chạy nếu DB chưa ở phiên bản [schemaVersion].
  void runIfNeeded() {
    final settingBox = _db.get<AppSetting>();
    final current = settingBox
        .query(AppSetting_.key.equals(settingKey))
        .findFirstAndClose();
    if ((int.tryParse(current?.value ?? "") ?? 0) >= schemaVersion) return;

    _db.store.runInTransaction(TxMode.write, () {
      run();
      settingBox.put(
        AppSetting(key: settingKey, value: schemaVersion.toString()),
      );
    });
    debugPrint("🔄 Đã chuyển dữ liệu sang mô hình biến thể");
  }

  /// Chuyển dữ liệu (gọi trong transaction).
  void run() {
    final componentBox = _db.get<Component>();
    final variantBox = _db.get<ComponentVariant>();
    final optionBox = _db.get<ComponentOption>();
    final itemBox = _db.get<ProjectItem>();
    final stockBox = _db.get<StockItem>();
    final shops = _ShopResolver(_db.get<Shop>());

    for (final component in componentBox.getAll()) {
      final attributes = component.attributes;
      final stocks = stockBox
          .query(StockItem_.component.equals(component.id))
          .findAndClose();
      final items = itemBox
          .query(ProjectItem_.component.equals(component.id))
          .findAndClose();
      final options = optionBox
          .query(ComponentOption_.component.equals(component.id))
          .findAndClose();

      // --- 1. Biến thể ---
      final variants = <String, ComponentVariant>{
        for (final v in component.variants) Variants.key(v.selection): v,
      };

      bool isComplete(VariantSelection s) =>
          attributes.every((a) => s[a.name] != null);

      void addVariant(VariantSelection selection) {
        final key = Variants.key(selection);
        variants.putIfAbsent(
          key,
          () => ComponentVariant(
            selectionJson: Variants.encodeSelection(selection),
            lowStockThreshold: component.lowStockThreshold,
          )..component.targetId = component.id,
        );
      }

      if (variants.isEmpty) {
        if (attributes.isEmpty) {
          addVariant(const {});
        } else {
          for (final s in stocks) {
            final selection = Variants.sanitizeSelection(s.variant, attributes);
            if (isComplete(selection)) addVariant(selection);
          }
          for (final i in items) {
            final selection = Variants.sanitizeSelection(
              i.legacyVariant,
              attributes,
            );
            if (isComplete(selection)) addVariant(selection);
          }
          if (variants.isEmpty) {
            final all = Variants.combinations(
              attributes,
              max: maxGeneratedCombinations + 1,
            );
            if (all.length <= maxGeneratedCombinations) all.forEach(addVariant);
          }
          // Tuỳ chọn chỉ áp dụng cho biến thể chưa có => tạo biến thể đầu tiên khớp
          for (final o in options) {
            final availability = Variants.sanitizeAvailability(
              o.legacyAvailability,
              attributes,
            );
            final matched = variants.values.any(
              (v) => Variants.isAvailable(availability, v.selection),
            );
            if (!matched) {
              final first = Variants.combinations(
                attributes,
                max: 500,
              ).where((c) => Variants.isAvailable(availability, c)).firstOrNull;
              if (first != null) addVariant(first);
            }
          }
        }

        // Tồn kho cũ
        for (final s in stocks) {
          final key = Variants.key(
            Variants.sanitizeSelection(s.variant, attributes),
          );
          final variant = variants[key];
          if (variant == null) continue;
          variant.stock = (variant.stock ?? 0) + s.quantity;
          if (variant.location.isEmpty) variant.location = s.location;
        }
        variantBox.putMany(variants.values.toList());
      }

      // --- 2. Tuỳ chọn mua hàng ---
      for (final o in options) {
        var changed = false;
        if (o.shop.targetId == 0 && o.legacyShopName.trim().isNotEmpty) {
          o.shop.target = shops.resolve(o.legacyShopName);
          changed = true;
        }
        if (o.legacyShopName.isNotEmpty) {
          o.legacyShopName = "";
          changed = true;
        }
        if (o.variants.isEmpty) {
          final availability = Variants.sanitizeAvailability(
            o.legacyAvailability,
            attributes,
          );
          o.variants.addAll(
            variants.values.where(
              (v) => Variants.isAvailable(availability, v.selection),
            ),
          );
          o.legacyAvailabilityJson = "";
          changed = true;
        }
        if (changed) optionBox.put(o);
      }

      // --- 3. Linh kiện trong dự án ---
      for (final i in items) {
        if (i.variant.targetId != 0 && i.legacyVariantJson.isEmpty) continue;
        if (i.variant.targetId == 0) {
          final selection = Variants.sanitizeSelection(
            i.legacyVariant,
            attributes,
          );
          i.variant.target =
              variants[Variants.key(selection)] ??
              (attributes.isEmpty ? variants[""] : null);
        }
        i.legacyVariantJson = "";
        itemBox.put(i);
      }

      stockBox.removeMany(stocks.map((s) => s.id).toList());
    }
  }
}

/// Tìm shop theo tên (không phân biệt hoa thường), tạo mới nếu chưa có.
class _ShopResolver {
  final Box<Shop> _box;
  late final Map<String, Shop> _byName = {
    for (final s in _box.getAll()) s.name.trim().toLowerCase(): s,
  };

  _ShopResolver(this._box);

  Shop resolve(String name) {
    final key = name.trim().toLowerCase();
    return _byName.putIfAbsent(key, () {
      final shop = Shop(name: name.trim());
      _box.put(shop);
      return shop;
    });
  }
}
