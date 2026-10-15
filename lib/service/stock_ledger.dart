import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';

/// Mọi thay đổi tồn kho đi qua đây để ghi [StockLog].
/// Không tự mở transaction — nơi gọi bọc nếu cần ghi nhiều bản ghi cùng lúc.
class StockLedger {
  final _db = ObjectboxService.instance;

  /// Đặt tồn kho của [variant] thành [stock] (lưu biến thể) và ghi nhật ký.
  /// Không đổi => không ghi. Trả về bản ghi nhật ký (null nếu không đổi).
  StockLog? set(
    ComponentVariant variant,
    int? stock,
    StockReason reason, {
    int projectId = 0,
    String note = "",
  }) {
    final before = variant.stock;
    variant.stock = stock;
    _db.get<ComponentVariant>().put(variant);
    return log(
      variant,
      before,
      stock,
      reason,
      projectId: projectId,
      note: note,
    );
  }

  /// Cộng / trừ tồn kho (không xuống dưới 0; chưa theo dõi => bắt đầu từ 0).
  StockLog? adjust(
    ComponentVariant variant,
    int delta,
    StockReason reason, {
    int projectId = 0,
    String note = "",
  }) {
    final next = (variant.stock ?? 0) + delta;
    return set(
      variant,
      next < 0 ? 0 : next,
      reason,
      projectId: projectId,
      note: note,
    );
  }

  /// Chỉ ghi nhật ký (biến thể đã được lưu ở nơi khác).
  StockLog? log(
    ComponentVariant variant,
    int? before,
    int? after,
    StockReason reason, {
    int projectId = 0,
    String note = "",
  }) {
    if (before == after) return null;
    final component = variant.component.target;
    final label = [
      component?.name ?? "",
      if (!variant.isDefault) variant.labelFor(component?.attributes),
    ].where((s) => s.isNotEmpty).join(" · ");
    final entry =
        StockLog(
            before: before,
            after: after,
            reason: reason.name,
            note: note,
            label: label,
          )
          ..variant.targetId = variant.id
          ..project.targetId = projectId;
    _db.get<StockLog>().put(entry);
    return entry;
  }

  /// Nhật ký của 1 biến thể / 1 dự án / tất cả, mới nhất trước.
  List<StockLog> history({int? variantId, int? projectId, int limit = 0}) {
    Condition<StockLog>? condition;
    if (variantId != null) condition = StockLog_.variant.equals(variantId);
    if (projectId != null) {
      final byProject = StockLog_.project.equals(projectId);
      condition = condition == null ? byProject : condition & byProject;
    }
    final query =
        (_db.get<StockLog>().query(condition)
              ..order(StockLog_.at, flags: Order.descending)
              ..order(StockLog_.id, flags: Order.descending))
            .build();
    if (limit > 0) query.limit = limit;
    final result = query.find();
    query.close();
    return result;
  }

  /// Số cái đang trừ cho dự án theo biến thể: đã dùng - đã trả lại.
  Map<int, int> consumedBy(int projectId) {
    final result = <int, int>{};
    for (final entry in history(projectId: projectId)) {
      final id = entry.variant.targetId;
      if (id == 0) continue;
      switch (entry.stockReason) {
        case StockReason.projectUse || StockReason.projectReturn:
          result[id] = (result[id] ?? 0) - entry.delta;
        default:
      }
    }
    result.removeWhere((_, quantity) => quantity <= 0);
    return result;
  }
}
