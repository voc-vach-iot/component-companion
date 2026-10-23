import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/service/ai/catalog_assistant.dart';

/// Nhờ AI vẽ icon SVG kiểu nét (giống Lucide) cho 1 linh kiện / nhóm.
class SvgAssistant {
  SvgAssistant._();

  static String buildPrompt(String subject, {String hint = ""}) =>
      '''Vẽ 1 icon SVG cho: "${subject.trim()}"${hint.trim().isEmpty ? "" : " (${hint.trim()})"}.
Đây là icon cho app quản lý linh kiện điện tử; vẽ hình dáng thật hoặc ký hiệu mạch đặc trưng, dễ nhận ra ở cỡ 24px.
Yêu cầu: viewBox="0 0 24 24", fill="none", stroke="currentColor", stroke-width="2", stroke-linecap="round", stroke-linejoin="round", chỉ dùng path / line / rect / circle / polyline, không có chữ, không có màu cố định, dưới 1500 ký tự, kiểu icon nét đơn giản giống bộ Lucide.
Chỉ trả về đúng 1 object JSON (không markdown): {"svg": "<svg ...>...</svg>", "name": "tên ngắn tiếng Việt", "keywords": ["từ khoá"]}''';

  /// Lấy SVG trong câu trả lời: JSON `{"svg": ...}` hoặc thẻ `<svg>` trần.
  static ({String svg, String name, List<String> keywords}) parse(String text) {
    String svg = "";
    var name = "";
    var keywords = <String>[];
    try {
      final json = CatalogAssistant.extractJson(text);
      svg = "${json["svg"] ?? ""}";
      name = "${json["name"] ?? ""}".trim();
      keywords = [
        if (json["keywords"] is List)
          for (final k in json["keywords"] as List)
            if (k is String && k.trim().isNotEmpty) k.trim().toLowerCase(),
      ];
    } on AppException {
      svg = text;
    }
    final start = svg.indexOf("<svg");
    final end = svg.lastIndexOf("</svg>");
    if (start < 0 || end <= start) {
      throw ValidationException("Câu trả lời không có SVG");
    }
    return (
      svg: svg.substring(start, end + 6).replaceAll(r'\"', '"'),
      name: name,
      keywords: keywords,
    );
  }
}
