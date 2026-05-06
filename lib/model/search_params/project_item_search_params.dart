import 'package:dart_mappable/dart_mappable.dart';

part 'project_item_search_params.mapper.dart';

@MappableClass()
class ProjectItemSearchParams with ProjectItemSearchParamsMappable {
  int? projectId;
  int? projectOptionId;

  ProjectItemSearchParams({this.projectId, this.projectOptionId});
}
