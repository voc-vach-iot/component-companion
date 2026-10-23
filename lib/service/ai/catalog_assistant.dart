import 'dart:convert';

import 'package:component_companion/data/category_repository.dart';
import 'package:component_companion/data/component_type_repository.dart';
import 'package:component_companion/enum/category_color.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/service/ai/ai_runner.dart';

export 'package:component_companion/service/ai/ai_runner.dart'
    show AiFailedException, AiAttempt;
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/gemini_client.dart';

/// Danh mục AI gợi ý: dùng danh mục có sẵn ([existing]) hoặc tạo mới.
class CategorySuggestion {
  final Category? existing;
  final String name;
  final String description;
  final CategoryColor color;
  final List<String> keywords;
  final String iconSvg;

  /// Từ khoá nên thêm vào danh mục có sẵn (để lần sau tự nhận diện).
  final List<String> addKeywords;

  const CategorySuggestion({
    this.existing,
    this.name = "",
    this.description = "",
    this.color = CategoryColor.blue,
    this.keywords = const [],
    this.iconSvg = "",
    this.addKeywords = const [],
  });

  bool get isNew => existing == null && name.trim().isNotEmpty;
  bool get isEmpty => existing == null && !isNew;

  Category toCategory() => Category(
    name: name.trim(),
    description: description.trim(),
    colorValue: color.color.toARGB32(),
    iconSvg: iconSvg,
    keywords: [...keywords],
  );
}

/// Loại linh kiện AI gợi ý: dùng loại có sẵn hoặc tạo mới.
class TypeSuggestion {
  final ComponentType? existing;
  final String name;
  final List<String> keywords;
  final List<String> attributes;
  final String iconSvg;
  final List<String> addKeywords;

  const TypeSuggestion({
    this.existing,
    this.name = "",
    this.keywords = const [],
    this.attributes = const [],
    this.iconSvg = "",
    this.addKeywords = const [],
  });

  bool get isNew => existing == null && name.trim().isNotEmpty;
  bool get isEmpty => existing == null && !isNew;

  ComponentType toType(int categoryId) => ComponentType(
    name: name.trim(),
    defaultIconSvg: iconSvg,
    keywords: [...keywords],
    attributeTemplate: [...attributes],
  )..category.targetId = categoryId;
}

class CatalogSuggestion {
  final CategorySuggestion category;
  final TypeSuggestion type;
  final String note;

  /// Model đã trả lời (rỗng nếu dán tay).
  final String model;

  const CatalogSuggestion({
    required this.category,
    required this.type,
    this.note = "",
    this.model = "",
  });
}

/// Nhờ AI tìm hoặc tạo danh mục / loại phù hợp cho 1 linh kiện.
class CatalogAssistant {
  final List<Category> categories;
  final List<ComponentType> types;

  CatalogAssistant({required this.categories, required this.types});

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), " ").trim();

  /// Prompt gửi AI (cũng là nội dung sao chép khi hỏi tay).
  String buildPrompt({
    required String name,
    String description = "",
    List<String> attributes = const [],
  }) {
    final categoryById = {for (final c in categories) c.id: c};
    final buffer = StringBuffer()
      ..writeln(
        "Bạn là trợ lý phân loại linh kiện điện tử cho app quản lý kho linh kiện cá nhân (tiếng Việt).",
      )
      ..writeln()
      ..writeln("Quy ước của app:")
      ..writeln(
        "- Danh mục = nhóm lớn theo chức năng (VD Linh kiện thụ động, Bán dẫn, Vi điều khiển & board, Cảm biến, Nguồn & pin, Cơ khí - phụ kiện). Ít danh mục, mỗi danh mục rộng.",
      )
      ..writeln(
        "- Loại = loại linh kiện cụ thể trong 1 danh mục (VD Tụ hóa, Điện trở cắm, MOSFET, Board ESP32, Cảm biến nhiệt độ). Mỗi loại có danh mục gợi ý.",
      )
      ..writeln(
        "- Từ khoá: chữ thường, tiếng Việt có dấu và tiếng Anh, dùng để tự nhận diện từ tên linh kiện (VD \"tụ hóa\", \"electrolytic\"). Không trùng từ khoá đã có ở danh mục / loại khác.",
      )
      ..writeln(
        "- Thuộc tính của loại = thông số tách biến thể (VD Điện dung, Điện áp; Điện trở, Công suất). Không đưa quy cách gói / shop vào.",
      )
      ..writeln(
        "- Ưu tiên dùng danh mục / loại CÓ SẴN nếu phù hợp; chỉ đề xuất tạo mới khi thật sự không có cái nào hợp.",
      )
      ..writeln(
        "- Sản phẩm là combo nhiều linh kiện (VD \"Combo LCD1602 + PCF8574\", \"vít kèm ốc\") => phân loại theo linh kiện CHÍNH (LCD, vít); app quản lý combo riêng.",
      )
      ..writeln()
      ..writeln("Linh kiện cần phân loại:")
      ..writeln("- Tên: ${_clean(name)}");
    if (description.trim().isNotEmpty) {
      buffer.writeln("- Mô tả: ${_clean(description)}");
    }
    if (attributes.isNotEmpty) {
      buffer.writeln("- Thuộc tính: ${attributes.join(", ")}");
    }
    buffer
      ..writeln()
      ..writeln("Danh mục có sẵn (tên | từ khoá):");
    for (final c in categories) {
      buffer.writeln("- ${c.name} | ${c.keywords.join(", ")}");
    }
    if (categories.isEmpty) buffer.writeln("(chưa có)");
    buffer
      ..writeln()
      ..writeln("Loại có sẵn (tên | danh mục | từ khoá):");
    for (final t in types) {
      buffer.writeln(
        "- ${t.name} | ${categoryById[t.category.targetId]?.name ?? "-"} | ${t.keywords.join(", ")}",
      );
    }
    if (types.isEmpty) buffer.writeln("(chưa có)");
    buffer
      ..writeln()
      ..writeln(
        "Màu danh mục chọn 1 trong: ${CategoryColor.values.map((c) => c.name).join(", ")}.",
      )
      ..writeln(
        "Icon SVG (chỉ khi tạo mới): viewBox=\"0 0 24 24\", fill=\"none\", stroke=\"currentColor\", stroke-width=\"2\", stroke-linecap=\"round\", stroke-linejoin=\"round\", kiểu icon nét đơn giản như Lucide, không có chữ, dưới 1500 ký tự, vẽ hình dáng / ký hiệu đặc trưng của linh kiện.",
      )
      ..writeln()
      ..writeln(
        "Chỉ trả về đúng 1 object JSON (không markdown, không giải thích ngoài JSON) theo mẫu:",
      )
      ..writeln('''{
  "category": {
    "existing": "tên danh mục có sẵn, hoặc null nếu tạo mới",
    "new": null hoặc {"name": "", "description": "", "color": "blue", "keywords": [""], "iconSvg": "<svg ...>...</svg>"},
    "addKeywords": ["từ khoá nên thêm vào danh mục có sẵn để lần sau tự nhận diện, có thể rỗng"]
  },
  "type": {
    "existing": "tên loại có sẵn, hoặc null nếu tạo mới",
    "new": null hoặc {"name": "", "keywords": [""], "attributes": ["thuộc tính biến thể"], "iconSvg": "<svg ...>...</svg>"},
    "addKeywords": []
  },
  "note": "1 câu giải thích ngắn bằng tiếng Việt"
}''');
    return buffer.toString();
  }

  /// Lấy object JSON trong câu trả lời (bỏ ```json, chữ thừa trước / sau).
  static Map<String, dynamic> extractJson(String text) {
    var s = text.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(s);
    if (fence != null) s = fence[1]!.trim();
    final start = s.indexOf("{");
    final end = s.lastIndexOf("}");
    if (start < 0 || end <= start) {
      throw ValidationException("Câu trả lời không có JSON");
    }
    try {
      final data = jsonDecode(s.substring(start, end + 1));
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    throw ValidationException("JSON trong câu trả lời không hợp lệ");
  }

  static String _str(Object? v) => v is String ? v.trim() : "";

  static List<String> _list(Object? v) => [
    if (v is List)
      for (final x in v)
        if (x is String && x.trim().isNotEmpty) x.trim().toLowerCase(),
  ];

  static String _svg(Object? v) {
    final s = _str(v);
    final start = s.indexOf("<svg");
    final end = s.lastIndexOf("</svg>");
    return start >= 0 && end > start ? s.substring(start, end + 6) : "";
  }

  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Đọc câu trả lời của AI thành gợi ý (khớp tên có sẵn không phân biệt hoa
  /// thường; tên "mới" trùng cái có sẵn => dùng cái có sẵn).
  CatalogSuggestion parse(String text, {String model = ""}) {
    final json = extractJson(text);
    final c = json["category"] is Map ? json["category"] as Map : const {};
    final t = json["type"] is Map ? json["type"] as Map : const {};
    final cNew = c["new"] is Map ? c["new"] as Map : const {};
    final tNew = t["new"] is Map ? t["new"] as Map : const {};

    Category? findCategory(String name) => name.isEmpty
        ? null
        : categories.where((x) => _same(x.name, name)).firstOrNull;
    ComponentType? findType(String name) => name.isEmpty
        ? null
        : types.where((x) => _same(x.name, name)).firstOrNull;

    final category =
        findCategory(_str(c["existing"])) ?? findCategory(_str(cNew["name"]));
    final type = findType(_str(t["existing"])) ?? findType(_str(tNew["name"]));

    return CatalogSuggestion(
      category: CategorySuggestion(
        existing: category,
        name: category == null ? _str(cNew["name"]) : "",
        description: _str(cNew["description"]),
        color:
            CategoryColor.fromString(_str(cNew["color"])) ?? CategoryColor.blue,
        keywords: _list(cNew["keywords"]),
        iconSvg: _svg(cNew["iconSvg"]),
        addKeywords: category == null
            ? const []
            : _list(c["addKeywords"])
                  .where((k) => !category.keywords.any((x) => _same(x, k)))
                  .toList(),
      ),
      type: TypeSuggestion(
        existing: type,
        name: type == null ? _str(tNew["name"]) : "",
        keywords: _list(tNew["keywords"]),
        attributes: [
          if (tNew["attributes"] is List)
            for (final a in tNew["attributes"] as List)
              if (a is String && a.trim().isNotEmpty) a.trim(),
        ],
        iconSvg: _svg(tNew["iconSvg"]),
        addKeywords: type == null
            ? const []
            : _list(
                t["addKeywords"],
              ).where((k) => !type.keywords.any((x) => _same(x, k))).toList(),
      ),
      note: _str(json["note"]),
      model: model,
    );
  }

  /// Gọi lần lượt các model (xem [askModels]).
  Future<CatalogSuggestion> ask(
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

  /// Bỏ từ khoá đã thuộc danh mục / loại khác (repository sẽ báo lỗi).
  static List<String> _freeKeywords(
    List<String> keywords,
    Object? Function(String keyword) ownerOf,
  ) => [
    for (final k in keywords.toSet())
      if (ownerOf(k) == null) k,
  ];

  /// Ghi gợi ý: tạo danh mục / loại mới hoặc thêm từ khoá cho cái có sẵn.
  /// Trả về id danh mục / loại để chọn cho linh kiện (0 = không đổi).
  static Future<({int categoryId, int typeId})> apply(
    CatalogSuggestion s, {
    bool useCategory = true,
    bool useType = true,
    CategoryRepository? categoryRepository,
    ComponentTypeRepository? typeRepository,
  }) async {
    final categoryRepo = categoryRepository ?? CategoryRepository();
    final typeRepo = typeRepository ?? ComponentTypeRepository();
    var categoryId = 0;
    var typeId = 0;

    if (useCategory && !s.category.isEmpty) {
      if (s.category.existing case final c?) {
        categoryId = c.id;
        final add = _freeKeywords(
          s.category.addKeywords,
          (k) => categoryRepo.findKeywordOwner(k, excludeId: c.id),
        );
        if (add.isNotEmpty) {
          final fresh = categoryRepo.get(c.id)!;
          fresh.keywords = [...fresh.keywords, ...add];
          await categoryRepo.update(fresh);
        }
      } else {
        final category = s.category.toCategory();
        category.keywords = _freeKeywords(
          category.keywords,
          categoryRepo.findKeywordOwner,
        );
        categoryId = await categoryRepo.add(category);
      }
    }

    if (useType && !s.type.isEmpty) {
      if (s.type.existing case final t?) {
        typeId = t.id;
        final add = _freeKeywords(
          s.type.addKeywords,
          (k) => typeRepo.findKeywordOwner(k, excludeId: t.id),
        );
        if (add.isNotEmpty) {
          final fresh = typeRepo.get(t.id)!;
          fresh.keywords = [...fresh.keywords, ...add];
          await typeRepo.update(fresh);
        }
      } else {
        final type = s.type.toType(categoryId);
        type.keywords = _freeKeywords(type.keywords, typeRepo.findKeywordOwner);
        typeId = await typeRepo.add(type);
      }
    }
    return (categoryId: categoryId, typeId: typeId);
  }
}
