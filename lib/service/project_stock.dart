import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/stock_ledger.dart';

/// 1 biến thể dự án dùng (gộp từ cấu hình đang chọn).
class ProjectStockLine {
  final Component component;
  final ComponentVariant variant;
  final int quantity;

  const ProjectStockLine(this.component, this.variant, this.quantity);

  /// Biến thể không theo dõi tồn kho => không trừ.
  bool get tracked => variant.stock != null;
  int get stock => variant.stock ?? 0;
  bool get enough => !tracked || stock >= quantity;

  /// Tồn kho sau khi trừ (không âm).
  int get after => stock >= quantity ? stock - quantity : 0;

  String get label => variant.isDefault
      ? component.name
      : "${component.name} · ${variant.labelFor(component.attributes)}";
}

/// Trừ kho khi dự án hoàn thành / cộng lại khi đổi trạng thái về trước.
/// Số đã trừ được tính từ nhật ký kho ([StockReason.projectUse] /
/// [StockReason.projectReturn] gắn với dự án).
class ProjectStockService {
  final _db = ObjectboxService.instance;
  final _ledger = StockLedger();

  /// Linh kiện của cấu hình đang chọn, gộp theo biến thể.
  List<ProjectStockLine> usage(Project project) {
    final byVariant = <int, ProjectStockLine>{};
    for (final item in project.configurationItems) {
      final component = item.component.target;
      final variant = item.variant.target;
      if (component == null || variant == null || item.quantity <= 0) continue;
      final old = byVariant[variant.id];
      byVariant[variant.id] = ProjectStockLine(
        component,
        variant,
        (old?.quantity ?? 0) + item.quantity,
      );
    }
    return byVariant.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  /// Số đang trừ cho dự án (để cộng lại).
  List<ProjectStockLine> consumed(Project project) {
    final quantities = _ledger.consumedBy(project.id);
    final variants = _db
        .get<ComponentVariant>()
        .getMany(quantities.keys.toList())
        .whereType<ComponentVariant>();
    return [
      for (final v in variants)
        if (v.component.target case final c?)
          ProjectStockLine(c, v, quantities[v.id]!),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  /// Trừ kho các dòng (bỏ qua biến thể không theo dõi). Trả về nhật ký để hoàn tác.
  List<StockLog> consume(Project project, List<ProjectStockLine> lines) =>
      _move(project, {
        for (final l in lines)
          if (l.tracked) l.variant.id: -l.quantity,
      }, StockReason.projectUse);

  /// Cộng lại kho. Trả về nhật ký để hoàn tác.
  List<StockLog> giveBack(Project project, List<ProjectStockLine> lines) =>
      _move(project, {
        for (final l in lines) l.variant.id: l.quantity,
      }, StockReason.projectReturn);

  /// Hoàn tác 1 lần trừ / cộng (ghi ngược lại để số đã trừ vẫn đúng).
  void revert(Project project, List<StockLog> logs) {
    final deltas = <int, int>{};
    StockReason? reason;
    for (final l in logs) {
      deltas[l.variant.targetId] = (deltas[l.variant.targetId] ?? 0) - l.delta;
      reason = l.stockReason == StockReason.projectUse
          ? StockReason.projectReturn
          : StockReason.projectUse;
    }
    if (reason != null) _move(project, deltas, reason, note: "Hoàn tác");
  }

  List<StockLog> _move(
    Project project,
    Map<int, int> deltas,
    StockReason reason, {
    String? note,
  }) {
    final box = _db.get<ComponentVariant>();
    return _db.store.runInTransaction(TxMode.write, () {
      final logs = <StockLog>[];
      for (final v in box.getMany(deltas.keys.toList())) {
        if (v == null) continue;
        final log = _ledger.adjust(
          v,
          deltas[v.id]!,
          reason,
          projectId: project.id,
          note: note ?? project.name,
        );
        if (log != null) logs.add(log);
      }
      return logs;
    });
  }
}
