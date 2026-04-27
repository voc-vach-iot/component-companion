import 'package:component_companion/model/search_params/paging_search_params.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'project_search_params.mapper.dart';

@MappableClass()
class ProjectSearchParams extends PagingSearchParams
    with ProjectSearchParamsMappable {
  String name;

  ProjectSearchParams({this.name = "", super.page = 0, super.size = 12});
}
