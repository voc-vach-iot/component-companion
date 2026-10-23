import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/model/entities/project.dart';

/// 1 dự án đang giữ hàng của 1 biến thể.
typedef StockHold = ({int projectId, String project, int quantity});

/// Tồn kho "đang giữ": linh kiện trong cấu hình đang chọn của các dự án
/// [ProjectStatus.inProgress]. Tránh tính 1 cái trong kho cho 2 dự án.
/// Phần dự án đã lấy khỏi kho ([consumed]) không còn nằm trong kho nên không
/// tính là đang giữ.
class StockReservations {
  /// variantId -> các dự án đang giữ.
  final Map<int, List<StockHold>> byVariant;

  const StockReservations(this.byVariant);

  static const empty = StockReservations({});

  factory StockReservations.of(
    Iterable<Project> projects, {
    Map<int, Map<int, int>> consumed = const {},
  }) {
    final result = <int, Map<int, StockHold>>{};
    for (final p in projects) {
      if (p.projectStatus != ProjectStatus.inProgress) continue;
      for (final item in p.configurationItems) {
        final variantId = item.variant.targetId;
        if (variantId == 0 || item.quantity <= 0) continue;
        final holds = result.putIfAbsent(variantId, () => {});
        final old = holds[p.id];
        holds[p.id] = (
          projectId: p.id,
          project: p.name,
          quantity: (old?.quantity ?? 0) + item.quantity,
        );
      }
    }
    result.forEach((variantId, holds) {
      for (final id in holds.keys.toList()) {
        final taken = consumed[id]?[variantId] ?? 0;
        if (taken <= 0) continue;
        final h = holds[id]!;
        final left = h.quantity - taken;
        if (left > 0) {
          holds[id] = (
            projectId: h.projectId,
            project: h.project,
            quantity: left,
          );
        } else {
          holds.remove(id);
        }
      }
    });
    result.removeWhere((_, holds) => holds.isEmpty);
    return StockReservations({
      for (final e in result.entries) e.key: e.value.values.toList(),
    });
  }

  /// Dự án đang giữ biến thể (bỏ qua các dự án trong [except]).
  List<StockHold> holds(int variantId, {Set<int> except = const {}}) => [
    for (final h in byVariant[variantId] ?? const <StockHold>[])
      if (!except.contains(h.projectId)) h,
  ];

  int reserved(int variantId, {Set<int> except = const {}}) =>
      holds(variantId, except: except).fold(0, (s, h) => s + h.quantity);

  /// Tổng đang giữ theo biến thể (bỏ qua các dự án trong [except]).
  Map<int, int> totals({Set<int> except = const {}}) => {
    for (final id in byVariant.keys)
      if (reserved(id, except: except) case final r when r > 0) id: r,
  };

  /// "Robot (4), Đèn (2)".
  static String describe(List<StockHold> holds) =>
      holds.map((h) => "${h.project} (${h.quantity})").join(", ");
}
