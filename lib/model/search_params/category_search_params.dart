import 'package:component_companion/model/search_params/paging_search_params.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_search_params.mapper.dart';

@MappableClass()
class CategorySearchParams extends PagingSearchParams
    with CategorySearchParamsMappable {
  final String name;

  CategorySearchParams({this.name = "", super.page = 0, super.size = 12});
}
