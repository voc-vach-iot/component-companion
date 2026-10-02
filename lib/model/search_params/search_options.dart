import 'package:dart_mappable/dart_mappable.dart';

part 'search_options.mapper.dart';

/// Cách khớp chuỗi tìm kiếm.
@MappableEnum()
enum SearchMatchMode {
  contains("Chứa chuỗi", "Tên chứa nguyên chuỗi đã nhập"),
  allWords("Chứa tất cả các từ", "Mọi từ đều xuất hiện, không cần theo thứ tự"),
  wholeWord("Khớp nguyên từ", "Chuỗi đã nhập phải là một (cụm) từ hoàn chỉnh"),
  startsWith("Bắt đầu bằng", "Tên bắt đầu bằng chuỗi đã nhập"),
  allChars(
    "Chứa tất cả ký tự",
    "Các ký tự xuất hiện theo thứ tự, có thể cách nhau (VD: 'tph' khớp 'Tụ phân cực')",
  );

  final String label;
  final String description;

  const SearchMatchMode(this.label, this.description);
}

/// Phân biệt hoa thường.
@MappableEnum()
enum SearchCaseMode {
  smart("Thông minh", "Không phân biệt, trừ khi chuỗi tìm có chữ hoa"),
  insensitive("Không phân biệt", "Luôn bỏ qua hoa/thường"),
  sensitive("Phân biệt", "Luôn phân biệt hoa/thường");

  final String label;
  final String description;

  const SearchCaseMode(this.label, this.description);
}

@MappableClass()
class SearchOptions with SearchOptionsMappable {
  final SearchMatchMode matchMode;
  final SearchCaseMode caseMode;

  /// Bỏ dấu tiếng Việt / ký tự đặc biệt về ASCII trước khi so khớp (µ → u, Ω → ohm).
  final bool normalize;

  const SearchOptions({
    this.matchMode = SearchMatchMode.contains,
    this.caseMode = SearchCaseMode.smart,
    this.normalize = true,
  });

  static SearchOptions fromJson(String json) =>
      SearchOptionsMapper.fromJson(json);
}
