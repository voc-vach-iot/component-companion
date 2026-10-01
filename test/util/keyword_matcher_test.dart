import 'dart:convert';
import 'dart:io';

import 'package:component_companion/util/keyword_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Seed = ({String name, List<String> keywords, String? categoryName});

List<_Seed> _loadSeeds(String path) {
  final list = jsonDecode(File(path).readAsStringSync()) as List;
  return [
    for (final item in list.cast<Map<String, dynamic>>())
      (
        name: item["name"] as String,
        keywords: (item["keywords"] as List).cast<String>(),
        categoryName: item["categoryName"] as String?,
      ),
  ];
}

void main() {
  final categories = _loadSeeds("assets/seed/categories.json");
  final types = _loadSeeds("assets/seed/component_types.json");

  String? categoryOf(String name) {
    final category = KeywordMatcher.bestMatch(
      name,
      categories,
      (c) => c.keywords,
    );
    return category?.name ??
        KeywordMatcher.bestMatch(name, types, (t) => t.keywords)?.categoryName;
  }

  String? typeOf(String name) =>
      KeywordMatcher.bestMatch(name, types, (t) => t.keywords)?.name;

  group("normalize", () {
    test("lowercase, trim, gộp khoảng trắng", () {
      expect(KeywordMatcher.normalize("  Tụ   HÓA "), "tụ hóa");
    });

    test("normalizeAll loại bỏ rỗng và trùng", () {
      expect(KeywordMatcher.normalizeAll(["LED", "led ", "", " Tụ"]), [
        "led",
        "tụ",
      ]);
    });
  });

  group("score", () {
    test("từ ngắn phải khớp nguyên từ", () {
      expect(KeywordMatcher.score("keo silicone", "ic"), 0);
      expect(KeywordMatcher.score("ic lm358", "ic"), 2);
    });

    test("từ dài cho phép khớp tiền tố", () {
      expect(KeywordMatcher.score("stm32f103 blue pill", "stm32"), 5);
    });

    test("keyword nhiều từ không cần liền nhau", () {
      expect(
        KeywordMatcher.score("điện trở 10k 1206 1%", "điện trở 1206"),
        "điện trở 1206".length,
      );
    });
  });

  group("seed data", () {
    final cases = {
      "Điện trở 10K 1206 1%": ("Linh kiện thụ động", "Điện trở dán (SMD)"),
      "Điện trở 100K 1/4W 1%": ("Linh kiện thụ động", "Điện trở cắm (1/4W)"),
      "Điện trở sứ 5W 10R": ("Linh kiện thụ động", "Điện trở sứ (công suất)"),
      "Tụ gốm 50V 100nF (104)": ("Linh kiện thụ động", "Tụ gốm"),
      "Tụ hóa 470uF 16V 8x16mm": ("Linh kiện thụ động", "Tụ hóa"),
      "Đế IC DIP-16 tròn": ("Cổng & Đầu nối", "Đế IC / Đế nạp"),
      "Núm triết áp nhựa": ("Cơ khí & Hộp đựng", "Núm xoay"),
      "Triết áp đơn 3 chân": ("Linh kiện thụ động", "Biến trở / Chiết áp"),
      "LED WS2812B 5V RGB": ("Đèn báo & LED", "LED địa chỉ WS2812"),
      "Module USB → ESP8266 ESP-01/01S": (
        "Mạch nạp & Debug",
        "Adapter nạp ESP-01",
      ),
      "Kìm cắt chân linh kiện PLATO 125mm": ("Dụng cụ cầm tay", "Kìm"),
    };

    cases.forEach((name, expected) {
      test(name, () {
        expect(categoryOf(name), expected.$1);
        expect(typeOf(name), expected.$2);
      });
    });

    test("keyword không trùng giữa các danh mục / các loại", () {
      for (final seeds in [categories, types]) {
        final all = [for (final s in seeds) ...s.keywords];
        expect(all.toSet().length, all.length);
      }
    });
  });
}
