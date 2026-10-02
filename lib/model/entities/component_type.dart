import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:objectbox/objectbox.dart';

part 'component_type.mapper.dart';

/// Loại linh kiện (trở sứ, tụ hóa, ...): cung cấp icon mặc định cho linh kiện
/// và gợi ý danh mục khi tự động phân loại.
@MappableClass(
  generateMethods: GenerateMethods.encode | GenerateMethods.decode,
  caseStyle: CaseStyle.camelCase,
)
@Entity()
class ComponentType with ComponentTypeMappable {
  @Id()
  int id;
  String name;

  /// Icon SVG mặc định cho các linh kiện thuộc loại này.
  String defaultIconSvg;

  /// Từ khóa dùng để tự động phân loại linh kiện theo tên (đã chuẩn hóa lowercase).
  List<String> keywords;

  /// Tên các thuộc tính biến thể gợi ý khi tạo linh kiện thuộc loại này
  /// (VD Vít: ["Chiều dài", "Kiểu"]).
  List<String> attributeTemplate;

  /// Danh mục gợi ý khi linh kiện được nhận diện thuộc loại này.
  final category = ToOne<Category>();

  @Backlink("type")
  final components = ToMany<Component>();

  ComponentType({
    this.id = 0,
    required this.name,
    this.defaultIconSvg = "",
    List<String>? keywords,
    List<String>? attributeTemplate,
  }) : keywords = keywords ?? [],
       attributeTemplate = attributeTemplate ?? [];

  // --- Helper methods ---
  static ComponentType fromMap(Map<String, dynamic> map) =>
      ComponentTypeMapper.fromMap(map);

  static ComponentType fromJson(String json) =>
      ComponentTypeMapper.fromJson(json);
}
