import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/component_variant.dart';
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

  /// [CŨ] Ngưỡng cảnh báo cấp linh kiện, nay nằm ở từng biến thể. Dùng làm giá
  /// trị mặc định khi tạo biến thể mới.
  int lowStockThreshold;

  @Backlink("component")
  final options = ToMany<ComponentOption>();

  @Backlink("component")
  final projectItem = ToMany<ProjectItem>();

  final category = ToOne<Category>();

  final type = ToOne<ComponentType>();

  /// [CŨ] Tồn kho trước khi có bảng biến thể (chỉ dùng để chuyển dữ liệu).
  @Backlink("component")
  final stockItems = ToMany<StockItem>();

  @Backlink("component")
  final variants = ToMany<ComponentVariant>();

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

  /// Biến thể sắp theo thứ tự giá trị thuộc tính.
  List<ComponentVariant> get sortedVariants {
    final attrs = attributes;
    int rank(ComponentVariant v) {
      var r = 0;
      for (final a in attrs) {
        final i = a.values.indexOf(v.selection[a.name] ?? "");
        r = r * 1000 + (i < 0 ? 999 : i);
      }
      return r;
    }

    return variants.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// Tổng tồn kho các biến thể đang theo dõi. null = chưa theo dõi biến thể nào.
  int? get stockTotal {
    final tracked = variants.where((v) => v.stock != null);
    if (tracked.isEmpty) return null;
    return tracked.fold<int>(0, (sum, v) => sum + v.stock!);
  }

  /// Số biến thể hết / sắp hết hàng.
  int get outCount => variants.where((v) => v.isOut).length;
  int get lowCount => variants.where((v) => v.isLow && !v.isOut).length;

  @MappableField(key: "optionsList")
  List<ComponentOption> get optionsList => options.toList();

  // Helper methods
  static Component fromMap(Map<String, dynamic> map) =>
      ComponentMapper.fromMap(map);

  static Component fromJson(String json) => ComponentMapper.fromJson(json);
}
