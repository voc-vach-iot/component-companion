import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/util/text_search.dart';

/// Chữ phụ để tìm linh kiện trong ô chọn, ngoài tên: danh mục, loại, từ khoá
/// của loại / danh mục và giá trị biến thể (VD gõ "tụ 100uF" ra "Tụ hóa").
class ComponentSearch {
  static List<String> keywords(Component c) => [
    if (c.category.target case final category?) ...[
      category.name,
      ...category.keywords,
    ],
    if (c.type.target case final type?) ...[type.name, ...type.keywords],
    for (final a in c.attributes) ...a.values,
  ];

  /// Như [keywords] cho 1 biến thể: chỉ lấy giá trị của chính biến thể đó.
  static List<String> variantKeywords(ComponentVariant v) {
    final c = v.component.target;
    return [
      if (c?.category.target case final category?) ...[
        category.name,
        ...category.keywords,
      ],
      if (c?.type.target case final type?) ...[type.name, ...type.keywords],
      ...v.selection.values,
    ];
  }

  /// Biến thể của [c] khớp nhiều giá trị nhất với chuỗi đã gõ khi tìm (VD
  /// "tụ 100uF 25V"); null nếu không khớp giá trị nào hoặc hoà nhau.
  static ComponentVariant? variantFromQuery(String query, Component c) {
    final search = TextSearch(
      query,
      const SearchOptions(caseMode: SearchCaseMode.insensitive),
    );
    if (search.isEmpty || !c.hasVariants) return null;
    ComponentVariant? best;
    var bestHits = 0;
    var tie = false;
    for (final v in c.sortedVariants) {
      final hits = v.selection.values
          .where((value) => search.containsWord(value))
          .length;
      if (hits > bestHits) {
        best = v;
        bestHits = hits;
        tie = false;
      } else if (hits == bestHits && hits > 0) {
        tie = true;
      }
    }
    return tie ? null : best;
  }
}
