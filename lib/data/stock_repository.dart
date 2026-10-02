import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stock_repository.g.dart';

@riverpod
StockRepository stockRepository(Ref ref) => StockRepository();

/// Một dòng tồn kho cần ghi (dùng khi lưu từ dialog).
typedef StockEntry = ({
  VariantSelection variant,
  int quantity,
  String location,
});

class StockRepository {
  final _db = ObjectboxService.instance;
  final _stockBox = ObjectboxService.instance.get<StockItem>();

  List<StockItem> stockOf(int componentId) =>
      _stockBox.query(StockItem_.component.equals(componentId)).findAndClose();

  /// Ghi đè toàn bộ tồn kho của linh kiện. Dòng có số lượng 0 và không có
  /// vị trí sẽ bị bỏ. Danh sách rỗng = bỏ theo dõi tồn kho.
  Future<void> saveStock(
    int componentId,
    List<StockEntry> entries, {
    required int lowStockThreshold,
  }) async {
    final componentBox = _db.get<Component>();
    final component = componentBox.get(componentId);
    if (component == null) {
      throw EntityNotFoundException(
        "Không tìm thấy linh kiện với id $componentId",
      );
    }

    _db.store.runInTransaction(TxMode.write, () {
      _stockBox.query(StockItem_.component.equals(componentId)).build()
        ..remove()
        ..close();

      // Gộp các dòng trùng biến thể
      final merged = <String, StockItem>{};
      for (final entry in entries) {
        final key = Variants.key(entry.variant);
        final item = merged.putIfAbsent(
          key,
          () =>
              StockItem(variantJson: Variants.encodeSelection(entry.variant))
                ..component.targetId = componentId,
        );
        item.quantity += entry.quantity;
        if (item.location.isEmpty) item.location = entry.location.trim();
      }
      _stockBox.putMany(merged.values.toList());

      component.lowStockThreshold = lowStockThreshold;
      componentBox.put(component);
    });
  }

  /// Cộng thêm (hoặc trừ đi nếu [delta] âm) tồn kho của 1 biến thể.
  Future<void> adjust(
    int componentId,
    VariantSelection variant,
    int delta, {
    String location = "",
  }) async {
    _db.store.runInTransaction(TxMode.write, () {
      final key = Variants.key(variant);
      final existing = stockOf(
        componentId,
      ).where((s) => Variants.key(s.variant) == key).firstOrNull;
      final item =
          existing ??
          (StockItem(
            variantJson: Variants.encodeSelection(variant),
            location: location,
          )..component.targetId = componentId);
      item.quantity = (item.quantity + delta).clamp(0, 1 << 31);
      _stockBox.put(item);
    });
  }
}
