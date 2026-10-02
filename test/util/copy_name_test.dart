import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/util/copy_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("nextCopyName không trùng và không lặp hậu tố", () {
    final existing = {"Tụ hóa", "Tụ hóa (bản sao)"};
    expect(nextCopyName("Tụ hóa", existing.contains), "Tụ hóa (bản sao 2)");
    expect(
      nextCopyName("Tụ hóa (bản sao)", existing.contains),
      "Tụ hóa (bản sao 2)",
    );
    expect(nextCopyName("Servo", existing.contains), "Servo (bản sao)");
  });

  test("toPage nhảy tới trang chứa focusId", () {
    final ids = List.generate(30, (i) => i + 1);
    final page = ids.toPage(page: 0, size: 12, focusId: 27, idOf: (i) => i);
    expect(page.currentPage, 2);
    expect(page.items, contains(27));
    expect(page.totalPages, 3);

    final notFound = ids.toPage(page: 1, size: 12, focusId: 99, idOf: (i) => i);
    expect(notFound.currentPage, 1);
  });
}
