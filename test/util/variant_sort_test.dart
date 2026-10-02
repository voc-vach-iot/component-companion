import 'package:component_companion/model/variant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("sắp xếp điện dung theo giá trị thật, hiểu tiền tố", () {
    expect(Variants.sortValues(["10uF", "0.1uF", "1uF", "0.22uF"]), [
      "0.1uF",
      "0.22uF",
      "1uF",
      "10uF",
    ]);
    expect(Variants.sortValues(["1uF", "100nF", "22pF"]), [
      "22pF",
      "100nF",
      "1uF",
    ]);
  });

  test("điện trở: R, K, M, kiểu 4K7 và Ω", () {
    expect(Variants.sortValues(["10K", "220R", "4K7", "1M", "1KΩ"]), [
      "220R",
      "1KΩ",
      "4K7",
      "10K",
      "1M",
    ]);
  });

  test("điện áp, chiều dài, chữ có số", () {
    expect(Variants.sortValues(["16V", "6.3V", "50V"]), ["6.3V", "16V", "50V"]);
    expect(Variants.sortValues(["10mm", "5mm", "8mm"]), ["5mm", "8mm", "10mm"]);
    expect(Variants.sortValues(["M10", "M2", "M3"]), ["M2", "M3", "M10"]);
    expect(Variants.sortValues(["Passive", "Active"]), ["Active", "Passive"]);
  });

  test("isSorted và đổi tên trong lựa chọn", () {
    expect(Variants.isSorted(["0.1uF", "1uF", "10uF"]), isTrue);
    expect(Variants.isSorted(["1uF", "0.1uF"]), isFalse);
    expect(
      Variants.applyRenames(
        {"Dung": "0.1u", "Áp": "16V"},
        const AttributeRenames(
          attributes: {"Dung": "Điện dung"},
          values: {
            "Dung": {"0.1u": "0.1uF"},
          },
        ),
      ),
      {"Điện dung": "0.1uF", "Áp": "16V"},
    );
  });
}
