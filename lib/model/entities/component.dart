import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/model/variant.dart';
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

  /// Thuộc tính biến thể dạng JSON (xem [Variants.encodeAttributes]).
  String attributesJson;

  /// Cảnh báo "sắp hết" khi tổng tồn kho <= ngưỡng này (0 = không cảnh báo).
  int lowStockThreshold;

  @Backlink("component")
  final options = ToMany<ComponentOption>();

  @Backlink("component")
  final projectItem = ToMany<ProjectItem>();

  final category = ToOne<Category>();

  final type = ToOne<ComponentType>();

  @Backlink("component")
  final stockItems = ToMany<StockItem>();

  Component({
    this.id = 0,
    required this.name,
    this.description = "",
    this.base64Image = "",
    this.iconSvg = "",
    this.attributesJson = "",
    this.lowStockThreshold = 0,
    List<ComponentOption>? options,
  }) {
    if (options != null) {
      this.options.clear();
      this.options.addAll(options);
    }
  }

  List<VariantAttribute> get attributes =>
      Variants.decodeAttributes(attributesJson);
  set attributes(List<VariantAttribute> value) =>
      attributesJson = Variants.encodeAttributes(value);

  bool get hasVariants => attributes.isNotEmpty;

  /// Tổng số lượng tồn kho (mọi biến thể). null = chưa theo dõi tồn kho.
  int? get stockTotal => stockItems.isEmpty
      ? null
      : stockItems.fold<int>(0, (sum, s) => sum + s.quantity);

  /// Tồn kho của 1 biến thể cụ thể.
  int stockOf(VariantSelection variant) {
    final key = Variants.key(variant);
    return stockItems
        .where((s) => Variants.key(s.variant) == key)
        .fold(0, (sum, s) => sum + s.quantity);
  }

  @MappableField(key: "optionsList")
  List<ComponentOption> get optionsList => options.toList();

  // Helper methods
  static Component fromMap(Map<String, dynamic> map) =>
      ComponentMapper.fromMap(map);

  static Component fromJson(String json) => ComponentMapper.fromJson(json);
}
