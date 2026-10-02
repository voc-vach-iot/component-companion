import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'variant_repository.g.dart';

@riverpod
VariantRepository variantRepository(Ref ref) => VariantRepository();

class VariantRepository {
  final _db = ObjectboxService.instance;
  final _variantBox = ObjectboxService.instance.get<ComponentVariant>();

  /// Biến thể của linh kiện (kèm tuỳ chọn mua để hiện giá rẻ nhất).
  Stream<List<ComponentVariant>> watchByComponent(int componentId) => _db
      .watchTables([
        _db.store.watch<ComponentVariant>(),
        _db.store.watch<ComponentOption>(),
        _db.store.watch<PriceRecord>(),
        _db.store.watch<Shop>(),
        _db.store.watch<Component>(),
      ])
      .map((_) {
        final component = _db.get<Component>().get(componentId);
        return component?.sortedVariants ?? const [];
      });

  List<ComponentVariant> byComponent(int componentId) => _variantBox
      .query(ComponentVariant_.component.equals(componentId))
      .findAndClose();

  void _validate(ComponentVariant variant) {
    variant.component.attach(_db.store);
    final component = _db.get<Component>().get(variant.component.targetId);
    if (component == null) {
      throw EntityNotFoundException("Không tìm thấy linh kiện của biến thể");
    }
    final attributes = component.attributes;
    variant.selection = Variants.sanitizeSelection(
      variant.selection,
      attributes,
    );
    final missing = attributes
        .where((a) => variant.selection[a.name] == null)
        .map((a) => a.name);
    if (missing.isNotEmpty) {
      throw ValidationException("Chưa chọn: ${missing.join(", ")}");
    }
    final key = Variants.key(variant.selection);
    final duplicate = byComponent(
      component.id,
    ).any((v) => v.id != variant.id && Variants.key(v.selection) == key);
    if (duplicate) {
      throw EntityAlreadyExistsException(
        "Biến thể '${variant.labelFor(attributes)}' đã tồn tại",
      );
    }
  }

  Future<int> add(ComponentVariant variant) async {
    variant.id = 0;
    _validate(variant);
    return _variantBox.put(variant);
  }

  Future<int> update(ComponentVariant variant) async {
    if (_variantBox.get(variant.id) == null) {
      throw EntityNotFoundException("Không tìm thấy biến thể ${variant.id}");
    }
    _validate(variant);
    return _variantBox.put(variant);
  }

  /// Tạo các biến thể còn thiếu trong [selections]. Trả về số biến thể đã tạo.
  Future<int> addMany(
    int componentId,
    List<VariantSelection> selections, {
    int lowStockThreshold = 0,
  }) async {
    final existing = byComponent(
      componentId,
    ).map((v) => Variants.key(v.selection)).toSet();
    final created = [
      for (final s in selections)
        if (existing.add(Variants.key(s)))
          ComponentVariant(
            selectionJson: Variants.encodeSelection(s),
            lowStockThreshold: lowStockThreshold,
          )..component.targetId = componentId,
    ];
    _variantBox.putMany(created);
    return created.length;
  }

  /// Cộng (hoặc trừ) tồn kho. Biến thể chưa theo dõi kho sẽ bắt đầu từ 0.
  Future<int> adjustStock(int variantId, int delta) async {
    final variant = _variantBox.get(variantId);
    if (variant == null) {
      throw EntityNotFoundException("Không tìm thấy biến thể $variantId");
    }
    final next = (variant.stock ?? 0) + delta;
    variant.stock = next < 0 ? 0 : next;
    return _variantBox.put(variant);
  }

  /// Xoá biến thể. Tuỳ chọn mua chỉ gỡ liên kết (không mất giá); linh kiện
  /// trong dự án đang dùng biến thể sẽ thành "chưa chọn biến thể".
  Future<bool> delete(int id) async {
    if (_variantBox.get(id) == null) {
      throw EntityNotFoundException("Không tìm thấy biến thể $id");
    }
    return _variantBox.remove(id);
  }
}
