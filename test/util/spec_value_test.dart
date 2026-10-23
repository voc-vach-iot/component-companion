import 'package:component_companion/util/spec_value.dart';
import 'package:component_companion/util/variant_finder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("đọc số kèm tiền tố / đơn vị", () {
    double? base(String s) => SpecValue.parse(s)?.base;
    expect(base("10K"), 10000);
    expect(base("4K7"), closeTo(4700, 1e-9));
    expect(base("2R2"), closeTo(2.2, 1e-9));
    expect(base("2,2uF"), closeTo(2.2e-6, 1e-15));
    expect(base("2000mAh"), closeTo(2, 1e-9));
    expect(base("2Ah"), 2);
    expect(base("5mm"), closeTo(0.005, 1e-12));
    expect(base("1.5 cm"), closeTo(0.015, 1e-12));
    expect(base("18650"), 18650);
    expect(base("50x50x0.5mm"), 50);
    expect(base("Active"), isNull);
    expect(SpecValue.parse("5V")!.unit, "V");
    expect(SpecValue.parse("100pcs")!.unit, "pcs");
    expect(SpecValue.parse("16GB")!.label, "GB");
  });

  test("giá trị theo đơn vị thường gặp, khác đơn vị => null", () {
    expect(VariantFinder.amountIn("2Ah", "mAh"), closeTo(2000, 1e-6));
    expect(VariantFinder.amountIn("3500mAh", "mAh"), closeTo(3500, 1e-6));
    expect(VariantFinder.amountIn("5V", "mAh"), isNull);
    expect(VariantFinder.commonUnit(["2000mAh", "3000mAh", "2Ah"]), "mAh");
    expect(VariantFinder.isNumeric(["2000mAh", "3000mAh", "Khác"]), isTrue);
    expect(VariantFinder.isNumeric(["Đỏ", "Xanh"]), isFalse);
  });
}
