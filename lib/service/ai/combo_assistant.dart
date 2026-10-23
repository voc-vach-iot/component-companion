import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/service/ai/ai_runner.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/catalog_assistant.dart';
import 'package:component_companion/service/ai/gemini_client.dart';
import 'package:component_companion/util/bom_parser.dart';

/// Kết quả AI tách 1 sản phẩm thành combo.
class ComboSuggestion {
  final bool isCombo;

  /// Số cái linh kiện chính (của dòng đang nhập) trong 1 combo.
  final int mainQuantity;

  /// Thành phần khớp được với biến thể có sẵn.
  final List<({ComponentVariant variant, int quantity})> parts;

  /// Thành phần khớp biến thể sắp tạo trong lần nhập (chỉ số trong
  /// [ComboAssistant.newLabels]).
  final List<({int index, int quantity})> newParts;

  /// Thành phần AI nêu nhưng chưa có trong kho.
  final List<({String name, int quantity})> missing;
  final String note;
  final String model;

  const ComboSuggestion({
    required this.isCombo,
    this.mainQuantity = 1,
    this.parts = const [],
    this.newParts = const [],
    this.missing = const [],
    this.note = "",
    this.model = "",
  });
}

/// Nhờ AI nhận ra sản phẩm mua (thường từ Shopee) là combo gồm những linh
/// kiện nào trong kho, VD "Combo LCD1602 + module I2C PCF8574".
class ComboAssistant {
  /// Biến thể có thể là thành phần combo (mọi linh kiện).
  final List<ComponentVariant> variants;

  /// Nhãn các biến thể sẽ tạo trong lần nhập này (chưa có trong kho).
  final List<String> newLabels;

  ComboAssistant(this.variants, {this.newLabels = const []});

  /// Nhãn "Tên linh kiện · biến thể" — cũng là chuỗi AI phải trả lại.
  static String labelOf(ComponentVariant v) => v.fullLabel;

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), " ").trim();

  String buildPrompt({
    required String product,
    String packName = "",
    int units = 1,
    required String main,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        "Bạn là trợ lý quản lý kho linh kiện điện tử cá nhân (tiếng Việt).",
      )
      ..writeln()
      ..writeln(
        "Người dùng mua 1 sản phẩm trên sàn TMĐT. Hãy xác định 1 gói / 1 lần mua sản phẩm này gồm những linh kiện nào (combo), VD:",
      )
      ..writeln(
        "- \"Combo LCD1602 + module I2C PCF8574\" = 1 LCD 1602 + 1 module PCF8574.",
      )
      ..writeln("- \"Jack XT60 đực cái 10 cặp\" = 10 đầu đực + 10 đầu cái.")
      ..writeln("- \"Vít M3 kèm ốc, 50 bộ\" = 50 vít M3 + 50 ốc M3.")
      ..writeln(
        "Nếu sản phẩm chỉ là 1 loại linh kiện (dù gói nhiều cái) thì không phải combo.",
      )
      ..writeln()
      ..writeln("Sản phẩm:")
      ..writeln("- Tên: ${_clean(product)}");
    if (packName.trim().isNotEmpty) {
      buffer.writeln("- Phân loại đã chọn: ${_clean(packName)}");
    }
    buffer
      ..writeln("- Số cái mỗi gói app đọc được: $units")
      ..writeln(
        "- Linh kiện chính người dùng đã gán cho sản phẩm: ${_clean(main)}",
      )
      ..writeln()
      ..writeln(
        "Linh kiện có sẵn trong kho (mỗi dòng 1 nhãn, dạng \"Tên linh kiện · biến thể\"):",
      );
    for (final v in variants) {
      buffer.writeln("- ${labelOf(v)}");
    }
    for (final label in newLabels) {
      buffer.writeln("- $label");
    }
    if (variants.isEmpty && newLabels.isEmpty) buffer.writeln("(chưa có)");
    buffer
      ..writeln()
      ..writeln(
        "Chỉ trả về đúng 1 object JSON (không markdown, không giải thích ngoài JSON) theo mẫu:",
      )
      ..writeln('''{
  "isCombo": true,
  "mainQuantity": 1,
  "parts": [
    {"item": "nhãn CHÉP ĐÚNG từ danh sách có sẵn, hoặc tên linh kiện nếu kho chưa có", "quantity": 1, "existing": true}
  ],
  "note": "1 câu giải thích ngắn bằng tiếng Việt"
}''')
      ..writeln(
        "mainQuantity = số cái linh kiện chính trong 1 gói; parts = các thành phần KHÁC linh kiện chính (không lặp lại linh kiện chính), quantity = số cái trong 1 gói.",
      );
    return buffer.toString();
  }

  static int _int(Object? v, int fallback) => switch (v) {
    final int n when n > 0 => n,
    final num n when n > 0 => n.round(),
    final String s => int.tryParse(s.trim()) ?? fallback,
    _ => fallback,
  };

  static String _norm(String s) => _clean(s).toLowerCase();

  /// Biến thể ứng với [item]: đúng nhãn, không thì đoán theo tên linh kiện
  /// rồi giá trị biến thể.
  ComponentVariant? match(String item) {
    final key = _norm(item);
    if (key.isEmpty) return null;
    final exact = variants.where((v) => _norm(labelOf(v)) == key).firstOrNull;
    if (exact != null) return exact;
    final components = {
      for (final c in variants.map((v) => v.component.target).nonNulls) c.id: c,
    };
    final component = BomParser.matchComponent(item, components.values);
    if (component == null) return null;
    final variant = BomParser.matchVariant(item, component);
    return variant ??
        (component.sortedVariants.length == 1
            ? component.sortedVariants.single
            : null);
  }

  ComboSuggestion parse(String text, {String model = ""}) {
    final json = CatalogAssistant.extractJson(text);
    final parts = <({ComponentVariant variant, int quantity})>[];
    final newParts = <({int index, int quantity})>[];
    final missing = <({String name, int quantity})>[];
    if (json["parts"] case final List list) {
      for (final p in list.whereType<Map>()) {
        final item = p["item"] is String ? (p["item"] as String).trim() : "";
        if (item.isEmpty) continue;
        final quantity = _int(p["quantity"], 1);
        final index = newLabels.indexWhere((l) => _norm(l) == _norm(item));
        if (index >= 0) {
          if (!newParts.any((x) => x.index == index)) {
            newParts.add((index: index, quantity: quantity));
          }
          continue;
        }
        final variant = match(item);
        if (variant == null) {
          missing.add((name: item, quantity: quantity));
        } else if (!parts.any((x) => x.variant.id == variant.id)) {
          parts.add((variant: variant, quantity: quantity));
        }
      }
    }
    return ComboSuggestion(
      isCombo:
          json["isCombo"] == true || parts.isNotEmpty || newParts.isNotEmpty,
      mainQuantity: _int(json["mainQuantity"], 1),
      parts: parts,
      newParts: newParts,
      missing: missing,
      note: json["note"] is String ? (json["note"] as String).trim() : "",
      model: model,
    );
  }

  Future<ComboSuggestion> ask(
    String prompt,
    AiSettings settings, {
    void Function(String model)? onTry,
    GeminiClient? client,
  }) => askModels(
    prompt,
    settings,
    (text, model) => parse(text, model: model),
    onTry: onTry,
    client: client,
  );
}
