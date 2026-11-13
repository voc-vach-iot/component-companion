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

/// Góc bắt đầu đánh số LED trong vùng chọn.
enum LedCorner {
  topLeft("Trên-trái"),
  topRight("Trên-phải"),
  bottomLeft("Dưới-trái"),
  bottomRight("Dưới-phải");

  final String label;
  const LedCorner(this.label);

  bool get isBottom => this == bottomLeft || this == bottomRight;
  bool get isRight => this == topRight || this == bottomRight;
}

/// Hình chữ nhật của 1 khay trên mặt trước kho (mm).
typedef TrayRect = ({int id, double x, double y, double w, double h});

/// Sắp xếp khay theo [order]. Khay được gom thành hàng (hoặc cột) khi tâm
/// của chúng lệch nhau chưa tới nửa kích thước khay nhỏ hơn.
///
/// [corner] quyết định hàng (cột) đầu tiên và chiều chạy của nó; zig-zag đảo
/// chiều ở các hàng (cột) sau.
List<int> sortTraysForLed(
  List<TrayRect> trays,
  LedOrder order, {
  LedCorner corner = LedCorner.topLeft,
}) {
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

  // Theo hàng: góc dưới => bắt đầu từ hàng cuối, góc phải => chạy phải → trái.
  // Theo cột: góc phải => bắt đầu từ cột cuối, góc dưới => chạy dưới → lên.
  final reverseLines = byRow ? corner.isBottom : corner.isRight;
  final reverseFirst = byRow ? corner.isRight : corner.isBottom;
  final orderedLines = reverseLines ? lines.reversed.toList() : lines;

  final result = <int>[];
  for (var i = 0; i < orderedLines.length; i++) {
    final line = orderedLines[i]..sort((a, b) => cross(a).compareTo(cross(b)));
    final flip = reverseFirst != (snake && i.isOdd);
    final ordered = flip ? line.reversed : line;
    result.addAll(ordered.map((t) => t.id));
  }
  return result;
}
