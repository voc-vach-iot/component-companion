import 'package:component_companion/util/rename_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("tìm / thay không phân biệt hoa thường mặc định", () {
    const r = RenameRule(find: "điện trở", replace: "Trở");
    expect(r.apply("Điện trở 10K"), "Trở 10K");
  });

  test("phân biệt hoa thường", () {
    const r = RenameRule(find: "abc", replace: "X", caseSensitive: true);
    expect(r.apply("ABC abc"), "ABC X");
  });

  test("ký tự đặc biệt được coi là chữ khi không bật regex", () {
    const r = RenameRule(find: "(Shopee)", replace: "");
    expect(r.apply("LCD (Shopee)"), "LCD");
  });

  test("regex với nhóm \$1", () {
    const r = RenameRule(find: r"(\d+)k", replace: r"$1 kΩ", regex: true);
    expect(r.apply("Trở 10k"), "Trở 10 kΩ");
  });

  test("regex sai báo lỗi", () {
    const r = RenameRule(find: "(", regex: true);
    expect(r.validate(), isNotNull);
  });

  test("tiền / hậu tố", () {
    const r = RenameRule(prefix: "IC ", suffix: " DIP");
    expect(r.apply("555"), "IC 555 DIP");
  });

  test("mẫu có biến", () {
    const r = RenameRule(useTemplate: true, template: "Gói {n} {dv}");
    expect(r.apply("abc", {"n": "10", "dv": "cái"}), "Gói 10 cái");
    const keep = RenameRule(useTemplate: true, template: "{old} (Shopee)");
    expect(keep.apply("LCD"), "LCD (Shopee)");
  });
}
