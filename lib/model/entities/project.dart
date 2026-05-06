import 'package:component_companion/enum/project_status.dart';
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
  String description;
  String base64Image;
  int updatedAt;
  String status;

  @Backlink("project")
  final baseItems = ToMany<ProjectItem>();

  @Backlink("project")
  final projectOptions = ToMany<ProjectOption>();

  Project({
    this.id = 0,
    required this.name,
    this.description = "",
    this.base64Image = "",
    this.updatedAt = 0,
    this.status = "",
  }) {
    if (status.isEmpty) {
      status = ProjectStatus.planning.name;
    }
    if (updatedAt == 0) {
      updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
  }

  ProjectStatus get projectStatus =>
      ProjectStatus.fromString(status) ?? ProjectStatus.planning;

  // Helper methods
  static Project fromMap(Map<String, dynamic> map) =>
      ProjectMapper.fromMap(map);

  static Project fromJson(String json) => ProjectMapper.fromJson(json);
}
