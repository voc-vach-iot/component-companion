import 'dart:math' as math;

/// Cách điền nhanh thứ tự LED cho các khay trong kho.
enum LedOrder {
  rows("Theo hàng (trái → phải)"),
  snakeRows("Theo hàng, zig-zag"),
  columns("Theo cột (trên → dưới)"),
  snakeColumns("Theo cột, zig-zag");

  final String label;
  const LedOrder(this.label);
}

/// Hình chữ nhật của 1 khay trên mặt trước kho (mm).
typedef TrayRect = ({int id, double x, double y, double w, double h});

/// Sắp xếp khay theo [order]. Khay được gom thành hàng (hoặc cột) khi tâm
/// của chúng lệch nhau chưa tới nửa kích thước khay nhỏ hơn.
List<int> sortTraysForLed(List<TrayRect> trays, LedOrder order) {
  final byRow = order == LedOrder.rows || order == LedOrder.snakeRows;
  final snake = order == LedOrder.snakeRows || order == LedOrder.snakeColumns;

  // Trục gom nhóm (hàng: y) và trục chạy trong nhóm (hàng: x)
  double main(TrayRect t) => byRow ? t.y + t.h / 2 : t.x + t.w / 2;
  double size(TrayRect t) => byRow ? t.h : t.w;
  double cross(TrayRect t) => byRow ? t.x : t.y;

  final sorted = [...trays]..sort((a, b) => main(a).compareTo(main(b)));
  final lines = <List<TrayRect>>[];
  for (final t in sorted) {
    final line = lines.lastOrNull;
    if (line != null) {
      final ref = line.first;
      final tolerance = math.min(size(ref), size(t)) / 2;
      if ((main(t) - main(ref)).abs() < tolerance) {
        line.add(t);
        continue;
      }
    }
    lines.add([t]);
  }

  final result = <int>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i]..sort((a, b) => cross(a).compareTo(cross(b)));
    final ordered = snake && i.isOdd ? line.reversed : line;
    result.addAll(ordered.map((t) => t.id));
  }
  return result;
}
