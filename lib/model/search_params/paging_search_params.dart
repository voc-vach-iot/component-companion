import 'package:dart_mappable/dart_mappable.dart';

part 'paging_search_params.mapper.dart';

@MappableClass()
class PagingSearchParams with PagingSearchParamsMappable {
  final int size;
  final int page;

  PagingSearchParams({required this.page, required this.size});
}
