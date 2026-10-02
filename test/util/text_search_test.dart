import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

String _marked(TextSearch search, String text) {
  final buffer = StringBuffer();
  var last = 0;
  for (final (start, end) in search.highlights(text)) {
    buffer
      ..write(text.substring(last, start))
      ..write('[')
      ..write(text.substring(start, end))
      ..write(']');
    last = end;
  }
  buffer.write(text.substring(last));
  return buffer.toString();
}

void main() {
  TextSearch s(
    String q, {
    SearchMatchMode mode = SearchMatchMode.contains,
    SearchCaseMode caseMode = SearchCaseMode.smart,
    bool normalize = true,
  }) => TextSearch(
    q,
    SearchOptions(matchMode: mode, caseMode: caseMode, normalize: normalize),
  );

  group("chuẩn hóa", () {
    test("bỏ dấu tiếng Việt", () {
      expect(s("tu hoa").matches("Tụ hóa 470uF"), isTrue);
      expect(_marked(s("tu hoa"), "Tụ hóa 470uF"), "[Tụ hóa] 470uF");
    });

    test("đ -> d", () {
      expect(s("dien tro").matches("Điện trở 10K"), isTrue);
    });

    test("µ -> u, Ω -> ohm", () {
      expect(s("100uf").matches("Tụ 100µF"), isTrue);
      expect(_marked(s("10kohm"), "Trở 10KΩ"), "Trở [10KΩ]");
    });

    test("tắt chuẩn hóa thì phải gõ đúng dấu", () {
      expect(s("tu hoa", normalize: false).matches("Tụ hóa"), isFalse);
      expect(s("tụ hóa", normalize: false).matches("Tụ hóa"), isTrue);
    });

    test("chuỗi dạng tổ hợp (NFD) vẫn highlight đúng", () {
      const nfd = "Tụ hóa";
      expect(_marked(s("tu hoa"), nfd), "[$nfd]");
    });
  });

  group("hoa thường", () {
    test("smart: chữ thường => không phân biệt", () {
      expect(s("esp").matches("ESP32"), isTrue);
    });

    test("smart: có chữ hoa => phân biệt", () {
      expect(s("ESP").matches("esp32"), isFalse);
      expect(s("ESP").matches("ESP32"), isTrue);
    });

    test("insensitive / sensitive", () {
      expect(
        s("ESP", caseMode: SearchCaseMode.insensitive).matches("esp"),
        isTrue,
      );
      expect(
        s("esp", caseMode: SearchCaseMode.sensitive).matches("ESP"),
        isFalse,
      );
    });
  });

  group("chế độ khớp", () {
    test("contains highlight mọi lần xuất hiện", () {
      expect(_marked(s("a"), "Banana"), "B[a]n[a]n[a]");
    });

    test("allWords không theo thứ tự", () {
      final search = s("hoa tu", mode: SearchMatchMode.allWords);
      expect(_marked(search, "Tụ hóa 100uF"), "[Tụ] [hóa] 100uF");
      expect(search.matches("Tụ gốm"), isFalse);
    });

    test("wholeWord", () {
      final search = s("led", mode: SearchMatchMode.wholeWord);
      expect(search.matches("LED 5mm"), isTrue);
      expect(search.matches("Ledger"), isFalse);
    });

    test("startsWith", () {
      final search = s("module", mode: SearchMatchMode.startsWith);
      expect(search.matches("Module relay"), isTrue);
      expect(search.matches("Mạch module"), isFalse);
    });

    test("allChars theo thứ tự", () {
      final search = s("tph", mode: SearchMatchMode.allChars);
      expect(_marked(search, "Tụ phân cực"), "[T]ụ [ph]ân cực");
      expect(search.matches("phân tụ"), isFalse);
    });

    test("allChars highlight cửa sổ ngắn nhất", () {
      final search = s("sao9", mode: SearchMatchMode.allChars);
      expect(_marked(search, "Servo (bản sao 9)"), "Servo (bản [sao] [9])");
    });

    test("rank ưu tiên khớp liền mạch", () {
      final search = s("tuhoa", mode: SearchMatchMode.allChars);
      expect(
        search.rank(["Mắt thu hồng ngoại", "Tụ hóa", "Ổ cứng"], (t) => t),
        ["Tụ hóa", "Mắt thu hồng ngoại"],
      );
    });

    test("chuỗi rỗng khớp tất cả, không highlight", () {
      expect(s("  ").matches("bất kỳ"), isTrue);
      expect(s("").highlights("bất kỳ"), isEmpty);
    });
  });
}
