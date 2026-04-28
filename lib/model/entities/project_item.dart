import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:objectbox/objectbox.dart';

part 'project_item.mapper.dart';

@MappableClass(
  generateMethods: GenerateMethods.encode | GenerateMethods.decode,
  caseStyle: CaseStyle.camelCase,
)
@Entity()
class ProjectItem with ProjectItemMappable {
  @Id()
  int id;
  int quantity;

  final component = ToOne<Component>();
  final componentOption = ToOne<ComponentOption>();
  final projectOption = ToOne<ProjectOption>();
  final project = ToOne<Project>();

  ProjectItem({this.id = 0, this.quantity = 1});

  // Helper methods
  static ProjectItem fromMap(Map<String, dynamic> map) =>
      ProjectItemMapper.fromMap(map);

  static ProjectItem fromJson(String json) => ProjectItemMapper.fromJson(json);
}
