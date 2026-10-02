import 'package:component_companion/model/search_params/search_options.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'paging_search_params.mapper.dart';

@MappableClass()
class PagingSearchParams with PagingSearchParamsMappable {
  final int size;
  final int page;

  /// Cách so khớp ô tìm kiếm (bỏ dấu, hoa thường, ...).
  final SearchOptions searchOptions;

  /// Nếu có: repository trả về trang chứa bản ghi này (dùng để focus phần tử vừa thêm).
  final int? focusId;

  PagingSearchParams({
    required this.page,
    required this.size,
    this.searchOptions = const SearchOptions(),
    this.focusId,
  });
}
