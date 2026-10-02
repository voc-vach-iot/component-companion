import 'dart:convert';

import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:component_companion/util/text_search.dart';

/// 1 dòng đọc được từ file đơn hàng / BOM.
class ImportRow {
  final String name;

  /// Phân loại hàng của shop (VD "10PCS", "8mm + Ốc") => tên tuỳ chọn.
  final String variant;
  final int price;
  final int units;

  /// Số lượng đã mua (số gói) — dùng để cộng tồn kho nếu chọn.
  final int quantity;
  final String link;
  final String shop;

  const ImportRow({
    required this.name,
    this.variant = "",
    this.price = 0,
    this.units = 1,
    this.quantity = 0,
    this.link = "",
    this.shop = "",
  });

  bool get hasOption =>
      price > 0 || link.isNotEmpty || shop.isNotEmpty || variant.isNotEmpty;
}

/// Kế hoạch nhập cho 1 dòng (đã nhận diện danh mục / loại / linh kiện có sẵn).
class ImportPlan {
  final ImportRow row;
  bool include;
  int categoryId;
  int typeId;

  /// Linh kiện đã có cùng tên (sẽ thêm tuỳ chọn vào) — null = tạo mới.
  final Component? existing;

  ImportPlan({
    required this.row,
    required this.categoryId,
    required this.typeId,
    this.existing,
    this.include = true,
  });
}

class ImportResult {
  final int created;
  final int optionsAdded;
  final int stocked;

  const ImportResult(this.created, this.optionsAdded, this.stocked);
}

class ImportService {
  final _db = ObjectboxService.instance;

  // Tên cột được nhận diện (so khớp không dấu, không phân biệt hoa thường)
  static const _nameKeys = [
    "clean_name",
    "ten linh kien",
    "ten san pham",
    "ten",
    "name",
    "san pham",
    "product",
    "raw_name",
  ];
  static const _variantKeys = [
    "variant",
    "phan loai",
    "phan loai hang",
    "bien the",
    "quy cach",
  ];
  static const _priceKeys = [
    "price",
    "gia",
    "don gia",
    "gia goi",
    "gia/goi",
    "unit_price",
  ];
  static const _unitsKeys = ["units", "so cai/goi", "so cai", "units_per_pack"];
  static const _quantityKeys = ["quantity", "qty", "so luong", "sl"];
  static const _linkKeys = ["link", "url", "duong dan"];
  static const _shopKeys = ["shop", "cua hang", "nguoi ban", "seller", "store"];

  static String _norm(String s) => TextSearch(
    s,
    const SearchOptions(caseMode: SearchCaseMode.insensitive),
  ).normalizedQuery;

  /// Đọc file CSV hoặc JSON (mảng object) thành các dòng.
  static List<ImportRow> parse(String content) {
    final text = content.trim();
    if (text.isEmpty) return const [];
    final List<Map<String, String>> records;
    if (text.startsWith("[")) {
      final Object? data;
      try {
        data = jsonDecode(text);
      } catch (_) {
        throw ValidationException("File JSON không hợp lệ");
      }
      if (data is! List) throw ValidationException("JSON phải là một mảng");
      records = [
        for (final item in data.whereType<Map>())
          {
            for (final e in item.entries)
              _norm("${e.key}"): e.value == null ? "" : "${e.value}",
          },
      ];
    } else {
      final rows = Csv.decode(text);
      if (rows.length < 2) {
        throw ValidationException(
          "CSV cần dòng tiêu đề và ít nhất 1 dòng dữ liệu",
        );
      }
      final header = rows.first.map(_norm).toList();
      records = [
        for (final row in rows.skip(1))
          {
            for (var i = 0; i < header.length && i < row.length; i++)
              header[i]: row[i],
          },
      ];
    }

    String pick(Map<String, String> r, List<String> keys) {
      for (final key in keys) {
        final value = r[key]?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return "";
    }

    int number(String s) =>
        int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    final result = <ImportRow>[];
    for (final r in records) {
      final name = pick(r, _nameKeys);
      if (name.isEmpty) continue;
      final units = number(pick(r, _unitsKeys));
      result.add(
        ImportRow(
          name: name,
          variant: pick(r, _variantKeys),
          price: number(pick(r, _priceKeys)),
          units: units <= 0 ? 1 : units,
          quantity: number(pick(r, _quantityKeys)),
          link: pick(r, _linkKeys),
          shop: pick(r, _shopKeys),
        ),
      );
    }
    if (result.isEmpty) {
      throw ValidationException(
        "Không tìm thấy cột tên linh kiện (cần cột: tên / name / clean_name)",
      );
    }
    return result;
  }

  /// Nhận diện danh mục, loại và linh kiện đã có cho từng dòng.
  List<ImportPlan> plan(List<ImportRow> rows) {
    final categories = _db.get<Category>().getAll();
    final types = _db.get<ComponentType>().getAll();
    final existing = {
      for (final c in _db.get<Component>().getAll()) c.name.toLowerCase(): c,
    };

    return [
      for (final row in rows)
        () {
          final found = existing[row.name.toLowerCase()];
          final type = KeywordMatcher.bestMatch(
            row.name,
            types,
            (t) => t.keywords,
          );
          final categoryId =
              KeywordMatcher.bestMatch(
                row.name,
                categories,
                (c) => c.keywords,
              )?.id ??
              type?.category.targetId ??
              0;
          return ImportPlan(
            row: row,
            existing: found,
            categoryId: found?.category.targetId ?? categoryId,
            typeId: found?.type.targetId ?? type?.id ?? 0,
          );
        }(),
    ];
  }

  /// Ghi các dòng được chọn. Dòng trùng tên trong cùng file được gộp vào
  /// cùng 1 linh kiện (mỗi dòng thành 1 tuỳ chọn).
  ImportResult apply(List<ImportPlan> plans, {bool addToStock = false}) {
    final componentBox = _db.get<Component>();
    final optionBox = _db.get<ComponentOption>();
    final priceBox = _db.get<PriceRecord>();
    final stockBox = _db.get<StockItem>();

    return _db.store.runInTransaction(TxMode.write, () {
      var created = 0;
      var optionsAdded = 0;
      var stocked = 0;
      final createdByName = <String, int>{};
      final now = DateTime.now();

      for (final plan in plans.where((p) => p.include)) {
        final row = plan.row;
        final key = row.name.toLowerCase();
        var componentId = plan.existing?.id ?? createdByName[key];
        if (componentId == null) {
          final component = Component(name: row.name)
            ..category.targetId = plan.categoryId
            ..type.targetId = plan.typeId;
          componentId = componentBox.put(component);
          createdByName[key] = componentId;
          created++;
        }

        if (row.hasOption) {
          final name = row.variant.isEmpty
              ? "Gói ${row.units} cái"
              : row.variant;
          final duplicate = optionBox
              .query(
                ComponentOption_.component.equals(componentId) &
                    ComponentOption_.name.equals(name) &
                    ComponentOption_.shop.equals(row.shop),
              )
              .findFirstAndClose();
          if (duplicate == null) {
            final option = ComponentOption(
              name: name,
              unitsPerPack: row.units,
              pricePerPack: row.price,
              link: row.link,
              shop: row.shop,
              priceCheckedAt: now,
            )..component.targetId = componentId;
            final optionId = optionBox.put(option);
            priceBox.put(
              PriceRecord(
                pricePerPack: row.price,
                unitsPerPack: row.units,
                recordedAt: now,
              )..option.targetId = optionId,
            );
            optionsAdded++;
          }
        }

        if (addToStock && row.quantity > 0) {
          final stock =
              stockBox
                  .query(
                    StockItem_.component.equals(componentId) &
                        StockItem_.variantJson.equals(""),
                  )
                  .findFirstAndClose() ??
              (StockItem()..component.targetId = componentId);
          stock.quantity += row.quantity * row.units;
          stockBox.put(stock);
          stocked++;
        }
      }
      return ImportResult(created, optionsAdded, stocked);
    });
  }
}
