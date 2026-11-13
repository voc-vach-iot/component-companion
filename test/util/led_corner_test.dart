import 'package:component_companion/util/led_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Lưới 5 cột x 4 hàng, id = hàng * 5 + cột
  final grid = [
    for (var r = 0; r < 4; r++)
      for (var c = 0; c < 5; c++)
        (id: r * 5 + c, x: c * 100.0, y: r * 100.0, w: 100.0, h: 100.0),
  ];
  List<TrayRect> rows(int from, int to) =>
      grid.where((t) => t.id ~/ 5 >= from && t.id ~/ 5 <= to).toList();

  test("mặc định góc trên-trái giữ hành vi cũ", () {
    expect(sortTraysForLed(rows(0, 1), LedOrder.snakeRows), [
      0,
      1,
      2,
      3,
      4,
      9,
      8,
      7,
      6,
      5,
    ]);
  });

  test("hàng dưới cùng, bắt đầu dưới-trái => trái → phải", () {
    expect(
      sortTraysForLed(rows(3, 3), LedOrder.rows, corner: LedCorner.bottomLeft),
      [15, 16, 17, 18, 19],
    );
  });

  test("3 hàng trên, dưới-phải, zig-zag theo hàng", () {
    final ids = sortTraysForLed(
      rows(0, 2),
      LedOrder.snakeRows,
      corner: LedCorner.bottomRight,
    );
    expect(ids.sublist(0, 5), [14, 13, 12, 11, 10]);
    expect(ids.sublist(5, 10), [5, 6, 7, 8, 9]);
    expect(ids.sublist(10), [4, 3, 2, 1, 0]);
    // start 26 (0-based) => 26..30, 31..35, 36..40
    expect(26 + ids.indexOf(10), 30);
    expect(26 + ids.indexOf(5), 31);
    expect(26 + ids.indexOf(0), 40);
  });

  test("theo cột, góc dưới-phải", () {
    final ids = sortTraysForLed(
      grid.where((t) => t.id % 5 >= 3).toList(),
      LedOrder.columns,
      corner: LedCorner.bottomRight,
    );
    expect(ids.take(4), [19, 14, 9, 4]);
  });
}
