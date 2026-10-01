/// Tự động phân loại linh kiện theo tên dựa trên danh sách keyword.
///
/// Quy tắc khớp 1 keyword với tên:
/// - Keyword gồm nhiều từ (tách bởi khoảng trắng): tất cả các từ đều phải xuất
///   hiện trong tên (không cần liền nhau). VD: "điện trở 1206" khớp
///   "Điện trở 10K 1206 1%".
/// - Mỗi từ phải bắt đầu ở đầu 1 từ trong tên. Từ ngắn (< 4 ký tự) phải khớp
///   nguyên từ để tránh khớp nhầm ("ic" không khớp "silicone"); từ dài có thể
///   khớp tiền tố ("stm32" khớp "STM32F103").
/// - Khi nhiều keyword cùng khớp, keyword dài nhất (cụ thể nhất) thắng.
class KeywordMatcher {
  KeywordMatcher._();

  static const _wordChar = r'[\p{L}\p{M}\p{N}]';
  static const _minPrefixLength = 4;

  /// Chuẩn hóa keyword trước khi lưu/so sánh: trim, lowercase, gộp khoảng trắng.
  static String normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Chuẩn hóa + loại bỏ keyword rỗng và trùng lặp (giữ thứ tự).
  static List<String> normalizeAll(Iterable<String> keywords) {
    final seen = <String>{};
    return [
      for (final keyword in keywords.map(normalize))
        if (keyword.isNotEmpty && seen.add(keyword)) keyword,
    ];
  }

  /// Điểm khớp của [keyword] với [name] (đã normalize). 0 = không khớp.
  static int score(String name, String keyword) {
    if (keyword.isEmpty) return 0;
    for (final token in keyword.split(' ')) {
      if (!_tokenPattern(token).hasMatch(name)) return 0;
    }
    return keyword.length;
  }

  /// Tìm phần tử có keyword khớp tốt nhất với [name]. Trả về null nếu không có.
  static T? bestMatch<T>(
    String name,
    Iterable<T> items,
    List<String> Function(T item) keywordsOf,
  ) {
    final normalizedName = normalize(name);
    if (normalizedName.isEmpty) return null;

    T? best;
    var bestScore = 0;
    for (final item in items) {
      for (final keyword in keywordsOf(item)) {
        final s = score(normalizedName, keyword);
        if (s > bestScore) {
          best = item;
          bestScore = s;
        }
      }
    }
    return best;
  }

  static final _patternCache = <String, RegExp>{};

  static RegExp _tokenPattern(String token) {
    return _patternCache.putIfAbsent(token, () {
      var pattern = '(?<!$_wordChar)${RegExp.escape(token)}';
      if (token.length < _minPrefixLength) pattern += '(?!$_wordChar)';
      return RegExp(pattern, unicode: true);
    });
  }
}
