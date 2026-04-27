import 'package:component_companion/model/search_params/paging_search_params.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'component_search_params.mapper.dart';

@MappableClass()
class ComponentSearchParams extends PagingSearchParams
    with ComponentSearchParamsMappable {
  int? projectId;
  int? projectOptionId;
  String name;

  ComponentSearchParams({
    this.projectId,
    this.projectOptionId,
    this.name = "",
    super.page = 0,
    super.size = 12,
  });
}
