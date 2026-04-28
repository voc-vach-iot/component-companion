import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:objectbox/objectbox.dart';

part 'project_option.mapper.dart';

@MappableClass(
  generateMethods: GenerateMethods.encode | GenerateMethods.decode,
  caseStyle: CaseStyle.camelCase,
)
@Entity()
class ProjectOption with ProjectOptionMappable {
  @Id()
  int id;
  String name;

  final project = ToOne<Project>();

  @Backlink("projectOption")
  final items = ToMany<ProjectItem>();

  ProjectOption({this.id = 0, required this.name});

  // --- Helper methods ---
  static ProjectOption fromMap(Map<String, dynamic> map) =>
      ProjectOptionMapper.fromMap(map);

  static ProjectOption fromJson(String json) =>
      ProjectOptionMapper.fromJson(json);
}
