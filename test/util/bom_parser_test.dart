import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/util/bom_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("dòng chữ: số lượng ở đầu / cuối / trong ngoặc", () {
    final lines = BomParser.parse('''
5x LM358
Điện trở 10K x10
3 ESP32-C3 SuperMini
Tụ 100nF: 4
LED đỏ (3)
Nút nhấn tact
Module ESP-01
Pin 18650 - 2
''');
    expect(lines, [
      (text: "LM358", quantity: 5),
      (text: "Điện trở 10K", quantity: 10),
      (text: "ESP32-C3 SuperMini", quantity: 3),
      (text: "Tụ 100nF", quantity: 4),
      (text: "LED đỏ", quantity: 3),
      (text: "Nút nhấn tact", quantity: 1),
      (text: "Module ESP-01", quantity: 1),
      (text: "Pin 18650", quantity: 2),
    ]);
  });

  test("bảng tính / BOM KiCad: bỏ dòng tiêu đề, cột số = số lượng", () {
    final lines = BomParser.parse(
      "Reference\tValue\tFootprint\tQty\n"
      "R1 R2\t10K\tR_0805\t2\n"
      "U1;LM358;SOIC-8;1\n",
    );
    expect(lines, [
      (text: "R1 R2 10K R_0805", quantity: 2),
      (text: "U1 LM358 SOIC-8", quantity: 1),
    ]);
  });
  test("đoán linh kiện theo từ khoá, bỏ dấu; không đủ giống => null", () {
    final components = [
      Component(name: "IC LM358"),
      Component(name: "Điện trở"),
      Component(name: "ESP32-C3 SuperMini"),
      Component(name: "Tụ hóa"),
    ];
    String? match(String text) =>
        BomParser.matchComponent(text, components)?.name;
    expect(match("LM358 DIP-8"), "IC LM358");
    expect(match("dien tro 10K 0805"), "Điện trở");
    expect(match("esp32-c3 supermini"), "ESP32-C3 SuperMini");
    expect(match("Động cơ bước"), isNull);
  });
}
