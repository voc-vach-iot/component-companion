import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/cupertino.dart';
import 'package:objectbox/objectbox.dart';

part 'category.mapper.dart';

@MappableClass(
  generateMethods: GenerateMethods.encode | GenerateMethods.decode,
  caseStyle: CaseStyle.camelCase,
)
@Entity()
class Category with CategoryMappable {
  @Id()
  int id;
  String name;
  String description;
  int colorValue;

  /// Icon dạng chuỗi SVG (dán từ Lucide, Font Awesome, ...). Rỗng => icon mặc định.
  String iconSvg;

  /// Từ khóa dùng để tự động phân loại linh kiện theo tên (đã chuẩn hóa lowercase).
  List<String> keywords;

  @Backlink("category")
  final component = ToMany<Component>();

  @Backlink("category")
  final types = ToMany<ComponentType>();

  Category({
    this.id = 0,
    required this.name,
    this.description = "",
    required this.colorValue,
    this.iconSvg = "",
    List<String>? keywords,
  }) : keywords = keywords ?? [];

  Color get color => Color(colorValue);

  // --- Helper methods ---
  static Category fromMap(Map<String, dynamic> map) =>
      CategoryMapper.fromMap(map);

  static Category fromJson(String json) => CategoryMapper.fromJson(json);
}
