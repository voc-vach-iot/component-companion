import 'package:component_companion/widget/common/pagination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("rút gọn trang bằng dấu …", () {
    // Trang 6/20 (0-based 5)
    expect(AppPagination.visiblePages(5, 20, 1), [0, null, 4, 5, 6, null, 19]);
    // Gần đầu: không có "…" thừa
    expect(AppPagination.visiblePages(0, 5, 1), [0, 1, null, 4]);
    expect(AppPagination.visiblePages(1, 5, 1), [0, 1, 2, 3, 4]);
    expect(AppPagination.visiblePages(0, 1, 1), [0]);
  });
}
