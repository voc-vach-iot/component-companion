import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/util/icon_csv.dart';
import 'package:flutter_test/flutter_test.dart';

const _svg = '<svg viewBox="0 0 24 24"><path d="M2 12h20"/></svg>';

void main() {
  test("có tiêu đề (tiếng Việt, đổi thứ tự cột), bỏ dòng lỗi", () {
    final csv = Csv.encode([
      ["Từ khoá", "Tên", "SVG"],
      ["tụ; capacitor", "Tụ điện", _svg],
      ["", "Thiếu SVG", ""],
      ["x", "", _svg],
    ]);
    final result = IconCsv.decode(csv, defaultPack: "Bộ A");
    expect(result.skipped, 2);
    final icon = result.icons.single;
    expect(icon.name, "Tụ điện");
    expect(icon.svg, _svg);
    expect(icon.pack, "Bộ A");
    expect(icon.keywords, ["tụ", "capacitor"]);
  });

  test("không tiêu đề: name, svg, keywords, pack", () {
    final result = IconCsv.decode(
      Csv.encode([
        ["Diode", _svg, "diode|điốt", "Ký hiệu"],
      ]),
      defaultPack: "x",
    );
    expect(result.icons.single.pack, "Ký hiệu");
    expect(result.icons.single.keywords, ["diode", "điốt"]);
  });

  test("xuất rồi nhập lại giữ nguyên", () {
    final first = IconCsv.decode(
      Csv.encode([
        ["Tụ", _svg, "a; b", "P"],
      ]),
      defaultPack: "x",
    ).icons;
    final again = IconCsv.decode(
      IconCsv.encode(first),
      defaultPack: "x",
    ).icons.single;
    expect(again.name, "Tụ");
    expect(again.svg, _svg);
    expect(again.keywords, ["a", "b"]);
    expect(again.pack, "P");
  });
}
