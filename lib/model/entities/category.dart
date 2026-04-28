import 'package:component_companion/enum/category_icon.dart';
import 'package:component_companion/model/entities/component.dart';
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
  int colorValue;
  String iconName;

  @Backlink("category")
  final component = ToMany<Component>();

  Category({
    this.id = 0,
    required this.name,
    required this.colorValue,
    this.iconName = "",
  }) {
    if (iconName == "") {
      iconName = CategoryIcon.box.toValue();
    }
  }

  IconData get icon => CategoryIcon.fromValue(iconName).icon;

  Color get color => Color(colorValue);

  // --- Helper methods ---
  static Category fromMap(Map<String, dynamic> map) =>
      CategoryMapper.fromMap(map);

  static Category fromJson(String json) => CategoryMapper.fromJson(json);
}
