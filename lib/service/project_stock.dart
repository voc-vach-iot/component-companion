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

  /// Phần chưa trừ: linh kiện cấu hình đang chọn trừ đi số đã trừ trước đó
  /// (đổi Hoàn thành -> trạng thái khác -> Hoàn thành không trừ 2 lần).
  List<ProjectStockLine> remaining(Project project) {
    final consumed = _ledger.consumedBy(project.id);
    return [
      for (final l in usage(project))
        if (l.quantity - (consumed[l.variant.id] ?? 0) case final q when q > 0)
          ProjectStockLine(l.component, l.variant, q),
    ];
  }

  /// Số đã lấy khỏi kho cho các dự án: variantId -> số cái.
  Map<int, int> allocated(Iterable<int> projectIds) {
    final result = <int, int>{};
    for (final id in projectIds) {
      _ledger.consumedBy(id).forEach((variantId, quantity) {
        result[variantId] = (result[variantId] ?? 0) + quantity;
      });
    }
    return result;
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

  /// Đánh dấu các dòng đã dùng cho dự án mà không trừ tồn kho (dự án làm
  /// trước khi dùng app, kho thực tế đã thiếu sẵn).
  List<StockLog> markConsumed(Project project, List<ProjectStockLine> lines) =>
      _mark(project, {for (final l in lines) l.variant.id: l.quantity});

  /// Bỏ đánh dấu (không cộng tồn kho), VD đánh dấu nhầm.
  List<StockLog> unmark(Project project, List<ProjectStockLine> lines) =>
      _mark(project, {for (final l in lines) l.variant.id: -l.quantity});

  List<StockLog> _mark(Project project, Map<int, int> quantities) {
    final box = _db.get<ComponentVariant>();
    return _db.store.runInTransaction(TxMode.write, () {
      final logs = <StockLog>[];
      for (final v in box.getMany(quantities.keys.toList())) {
        if (v == null) continue;
        final log = _ledger.mark(
          v,
          quantities[v.id]!,
          projectId: project.id,
          note: project.name,
        );
        if (log != null) logs.add(log);
      }
      return logs;
    });
  }

  /// Tình trạng kho của dự án: đã lấy / cần (theo cấu hình đang chọn).
  ({int consumed, int needed}) status(Project project) {
    final consumed = _ledger.consumedBy(project.id);
    var needed = 0;
    var taken = 0;
    for (final l in usage(project)) {
      needed += l.quantity;
      taken += (consumed[l.variant.id] ?? 0).clamp(0, l.quantity);
    }
    return (consumed: taken, needed: needed);
  }

  /// Hoàn tác 1 lần trừ / cộng / đánh dấu (ghi ngược lại để số đã trừ vẫn đúng).
  void revert(Project project, List<StockLog> logs) {
    final marks = logs.where((l) => l.stockReason == StockReason.projectMark);
    if (marks.isNotEmpty) {
      _mark(project, {for (final l in marks) l.variant.targetId: -l.marked});
      logs = logs.where((l) => !marks.contains(l)).toList();
    }
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
