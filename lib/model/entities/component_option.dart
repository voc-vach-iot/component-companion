import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:objectbox/objectbox.dart';

part 'component_option.mapper.dart';

@MappableClass(
  generateMethods: GenerateMethods.encode | GenerateMethods.decode,
  caseStyle: CaseStyle.camelCase,
)
@Entity()
class ComponentOption with ComponentOptionMappable {
  @Id()
  int id;
  String name;
  int unitsPerPack;
  double pricePerPack;

  final component = ToOne<Component>();

  @Backlink("componentOption")
  final projectItem = ToMany<ProjectItem>();

  ComponentOption({
    this.id = 0,
    required this.name,
    this.unitsPerPack = 1,
    required this.pricePerPack,
  });

  // --- Helper methods ---
  static ComponentOption fromMap(Map<String, dynamic> map) =>
      ComponentOptionMapper.fromMap(map);

  static ComponentOption fromJson(String json) =>
      ComponentOptionMapper.fromJson(json);
}
