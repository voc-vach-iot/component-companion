import 'package:dart_mappable/dart_mappable.dart';

part 'project_option_search_params.mapper.dart';

@MappableClass()
class ProjectOptionSearchParams {
  final int? projectId;
  final String name;

  ProjectOptionSearchParams({this.projectId, this.name = ""});
}
