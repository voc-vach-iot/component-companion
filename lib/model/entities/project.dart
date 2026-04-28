import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:objectbox/objectbox.dart';

part 'project.mapper.dart';

@MappableClass(
  generateMethods: GenerateMethods.encode | GenerateMethods.decode,
  caseStyle: CaseStyle.camelCase,
)
@Entity()
class Project with ProjectMappable {
  @Id()
  int id;
  String name;

  @Backlink("project")
  final baseItems = ToMany<ProjectItem>();

  final projectOptions = ToMany<ProjectOption>();

  Project({this.id = 0, required this.name});

  // Helper methods
  static Project fromMap(Map<String, dynamic> map) =>
      ProjectMapper.fromMap(map);

  static Project fromJson(String json) => ProjectMapper.fromJson(json);
}
