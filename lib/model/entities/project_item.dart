import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/variant.dart';
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

  /// Số lượng cần dùng (cái).
  int quantity;

  /// [CŨ] Biến thể dạng JSON trước khi có bảng biến thể (chỉ dùng để chuyển dữ liệu).
  @Property(uid: 8611361039882395797)
  String legacyVariantJson;

  final component = ToOne<Component>();
  final variant = ToOne<ComponentVariant>();
  final componentOption = ToOne<ComponentOption>();
  final projectOption = ToOne<ProjectOption>();
  final project = ToOne<Project>();

  ProjectItem({this.id = 0, this.quantity = 1, this.legacyVariantJson = ""});

  /// [CŨ] Biến thể dạng JSON (chỉ dùng để chuyển dữ liệu).
  VariantSelection get legacyVariant =>
      Variants.decodeSelection(legacyVariantJson);

  double get totalPrice =>
      (componentOption.target?.pricePerUnit ?? 0) * quantity;

  // Helper methods
  static ProjectItem fromMap(Map<String, dynamic> map) =>
      ProjectItemMapper.fromMap(map);

  static ProjectItem fromJson(String json) => ProjectItemMapper.fromJson(json);
}
