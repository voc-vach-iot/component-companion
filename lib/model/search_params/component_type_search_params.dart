import 'package:component_companion/model/search_params/paging_search_params.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'component_type_search_params.mapper.dart';

@MappableClass()
class ComponentTypeSearchParams extends PagingSearchParams
    with ComponentTypeSearchParamsMappable {
  final String name;

  ComponentTypeSearchParams({
    this.name = "",
    super.page = 0,
    super.size = 12,
    super.searchOptions,
    super.focusId,
  });
}
