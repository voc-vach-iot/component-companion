import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:objectbox/objectbox.dart';

/// Biến thể (SKU) của linh kiện: 1 tổ hợp thông số cụ thể, VD "5V · Active".
/// Là đơn vị quản lý tồn kho, chọn trong dự án và gắn tuỳ chọn mua hàng.
/// Linh kiện không có thuộc tính => có đúng 1 biến thể mặc định (selection rỗng).
@Entity()
class ComponentVariant {
  @Id()
  int id;

  /// Giá trị thuộc tính dạng JSON (xem [Variants.encodeSelection]).
  String selectionJson;

  /// Số lượng đang có (cái). null = chưa theo dõi tồn kho.
  int? stock;

  /// Vị trí cất, VD "Khay A - ô 3".
  String location;

  /// Cảnh báo sắp hết khi stock <= ngưỡng (0 = không cảnh báo).
  int lowStockThreshold;

  String note;

  final component = ToOne<Component>();

  @Backlink("variants")
  final options = ToMany<ComponentOption>();

  @Backlink("variant")
  final projectItems = ToMany<ProjectItem>();

  ComponentVariant({
    this.id = 0,
    this.selectionJson = "",
    this.stock,
    this.location = "",
    this.lowStockThreshold = 0,
    this.note = "",
  });

  VariantSelection get selection => Variants.decodeSelection(selectionJson);
  set selection(VariantSelection value) =>
      selectionJson = Variants.encodeSelection(value);

  bool get isDefault => selectionJson.isEmpty;

  /// Nhãn hiển thị theo thứ tự thuộc tính của linh kiện, VD "5V · Active".
  String labelFor(List<VariantAttribute>? attributes) =>
      isDefault ? "Mặc định" : Variants.label(selection, attributes);

  String get label => labelFor(component.target?.attributes);

  bool get isOut => stock == 0;

  bool get isLow =>
      stock != null && lowStockThreshold > 0 && stock! <= lowStockThreshold;
}
