import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:objectbox/objectbox.dart';

part 'component.mapper.dart';

@MappableClass(
  generateMethods: GenerateMethods.encode | GenerateMethods.decode,
  caseStyle: CaseStyle.camelCase,
)
@Entity()
class Component with ComponentMappable {
  @Id()
  int id;
  String name;
  String description;
  String base64Image;

  /// Icon SVG riêng của linh kiện (ưu tiên sau ảnh, trước icon mặc định của loại).
  String iconSvg;

  @Backlink("component")
  final options = ToMany<ComponentOption>();

  @Backlink("component")
  final projectItem = ToMany<ProjectItem>();

  final category = ToOne<Category>();

  final type = ToOne<ComponentType>();

  Component({
    this.id = 0,
    required this.name,
    this.description = "",
    this.base64Image = "",
    this.iconSvg = "",
    List<ComponentOption>? options,
  }) {
    if (options != null) {
      this.options.clear();
      this.options.addAll(options);
    }
  }

  @MappableField(key: "optionsList")
  List<ComponentOption> get optionsList => options.toList();

  // Helper methods
  static Component fromMap(Map<String, dynamic> map) =>
      ComponentMapper.fromMap(map);

  static Component fromJson(String json) => ComponentMapper.fromJson(json);
}
