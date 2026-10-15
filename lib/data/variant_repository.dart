import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/stock_ledger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'variant_repository.g.dart';

@riverpod
VariantRepository variantRepository(Ref ref) => VariantRepository();

class VariantRepository {
  final _db = ObjectboxService.instance;
  final _variantBox = ObjectboxService.instance.get<ComponentVariant>();
  final _ledger = StockLedger();

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

  ComponentVariant? get(int id) => _variantBox.get(id);

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
    return _db.store.runInTransaction(TxMode.write, () {
      final id = _variantBox.put(variant);
      _ledger.log(variant, null, variant.stock, StockReason.manual);
      return id;
    });
  }

  Future<int> update(ComponentVariant variant) async {
    final existing = _variantBox.get(variant.id);
    if (existing == null) {
      throw EntityNotFoundException("Không tìm thấy biến thể ${variant.id}");
    }
    _validate(variant);
    // Dialog sửa không có ô "đang về" => giữ nguyên
    variant.incoming = existing.incoming;
    return _db.store.runInTransaction(TxMode.write, () {
      final id = _variantBox.put(variant);
      _ledger.log(variant, existing.stock, variant.stock, StockReason.manual);
      return id;
    });
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
  Future<int> adjustStock(
    int variantId,
    int delta, {
    StockReason reason = StockReason.manual,
    String note = "",
  }) async {
    final variant = _variantBox.get(variantId);
    if (variant == null) {
      throw EntityNotFoundException("Không tìm thấy biến thể $variantId");
    }
    _db.store.runInTransaction(
      TxMode.write,
      () => _ledger.adjust(variant, delta, reason, note: note),
    );
    return variant.id;
  }

  /// Đặt lại tồn kho (dùng để hoàn tác nhập kho). null = chưa theo dõi.
  Future<void> restoreStocks(
    Map<int, int?> stocks, {
    StockReason reason = StockReason.undo,
  }) async {
    final variants = _variantBox
        .getMany(stocks.keys.toList())
        .whereType<ComponentVariant>()
        .toList();
    _db.store.runInTransaction(TxMode.write, () {
      for (final v in variants) {
        _ledger.set(v, stocks[v.id], reason);
      }
    });
  }

  /// Đã đặt mua: cộng vào "đang về" (variantId -> số cái).
  /// Trả về giá trị đang về cũ để hoàn tác.
  Future<Map<int, int>> addIncoming(Map<int, int> units) async {
    final previous = <int, int>{};
    _db.store.runInTransaction(TxMode.write, () {
      for (final v in _variantBox.getMany(units.keys.toList())) {
        if (v == null) continue;
        previous[v.id] = v.incoming;
        v.incoming = v.incoming + units[v.id]!;
        if (v.incoming < 0) v.incoming = 0;
        _variantBox.put(v);
      }
    });
    return previous;
  }

  /// Đặt lại số đang về (hoàn tác).
  Future<void> restoreIncoming(Map<int, int> incoming) async {
    final variants = _variantBox
        .getMany(incoming.keys.toList())
        .whereType<ComponentVariant>()
        .toList();
    for (final v in variants) {
      v.incoming = incoming[v.id]!;
    }
    _variantBox.putMany(variants);
  }

  /// Đã nhận hàng: chuyển toàn bộ "đang về" vào tồn kho.
  /// Trả về (tồn kho cũ, đang về cũ) để hoàn tác.
  Future<({Map<int, int?> stocks, Map<int, int> incoming})> receive(
    List<int> variantIds,
  ) async {
    final stocks = <int, int?>{};
    final incoming = <int, int>{};
    _db.store.runInTransaction(TxMode.write, () {
      for (final v in _variantBox.getMany(variantIds)) {
        if (v == null || v.incoming <= 0) continue;
        stocks[v.id] = v.stock;
        incoming[v.id] = v.incoming;
        final units = v.incoming;
        v.incoming = 0;
        _ledger.adjust(v, units, StockReason.received);
      }
    });
    return (stocks: stocks, incoming: incoming);
  }

  /// Biến thể đang có hàng đang về.
  Stream<List<ComponentVariant>> watchIncoming() => _db
      .watchTables([_db.store.watch<ComponentVariant>()])
      .map(
        (_) => _variantBox
            .query(ComponentVariant_.incoming.greaterThan(0))
            .findAndClose(),
      );

  /// Nhật ký kho của biến thể / toàn bộ (mới nhất trước).
  Stream<List<StockLog>> watchLogs({int? variantId, int limit = 0}) => _db
      .watchTables([_db.store.watch<StockLog>()])
      .map((_) => _ledger.history(variantId: variantId, limit: limit));

  /// Xoá biến thể. Tuỳ chọn mua chỉ gỡ liên kết (không mất giá); linh kiện
  /// trong dự án đang dùng biến thể sẽ thành "chưa chọn biến thể".
  Future<bool> delete(int id) async {
    if (_variantBox.get(id) == null) {
      throw EntityNotFoundException("Không tìm thấy biến thể $id");
    }
    return _variantBox.remove(id);
  }
}
