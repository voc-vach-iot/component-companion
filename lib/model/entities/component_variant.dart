import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/model/unit.dart';
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

  /// Số cái đã đặt mua, chưa nhận ("đang về").
  int incoming;

  /// Vị trí cất, VD "Khay A - ô 3".
  String location;

  /// Cảnh báo sắp hết khi stock <= ngưỡng (0 = không cảnh báo).
  int lowStockThreshold;

  String note;

  /// Ngăn cất trong [tray] (0 = ngăn đầu tiên).
  int compartmentIndex;

  final component = ToOne<Component>();

  /// Khay đang cất biến thể này trong kho thông minh (null = chưa có chỗ).
  final tray = ToOne<StorageTray>();

  @Backlink("variants")
  final options = ToMany<ComponentOption>();

  @Backlink("variant")
  final projectItems = ToMany<ProjectItem>();

  @Backlink("variant")
  final stockLogs = ToMany<StockLog>();

  ComponentVariant({
    this.id = 0,
    this.selectionJson = "",
    this.stock,
    this.incoming = 0,
    this.location = "",
    this.lowStockThreshold = 0,
    this.note = "",
    this.compartmentIndex = 0,
  });

  VariantSelection get selection => Variants.decodeSelection(selectionJson);
  set selection(VariantSelection value) =>
      selectionJson = Variants.encodeSelection(value);

  QuantityUnit get unit => component.target?.quantityUnit ?? QuantityUnit.piece;

  bool get isDefault => selectionJson.isEmpty;

  /// Nhãn hiển thị theo thứ tự thuộc tính của linh kiện, VD "5V · Active".
  String labelFor(List<VariantAttribute>? attributes) =>
      isDefault ? "Mặc định" : Variants.label(selection, attributes);

  String get label => labelFor(component.target?.attributes);

  /// "Tên linh kiện · biến thể" (biến thể mặc định: chỉ tên linh kiện).
  String get fullLabel {
    final c = component.target;
    if (c == null) return label;
    return isDefault ? c.name : "${c.name} · ${labelFor(c.attributes)}";
  }

  bool get hasPlace => tray.targetId != 0 && tray.target != null;

  /// "A1 / ngăn 2", hoặc rỗng nếu chưa có chỗ trong kho.
  String get placeLabel {
    final t = tray.target;
    return t == null ? "" : t.compartmentLabel(compartmentIndex);
  }

  bool get isOut => stock == 0;

  bool get isLow =>
      stock != null && lowStockThreshold > 0 && stock! <= lowStockThreshold;
}

/// Tình trạng tồn kho của biến thể (dùng để lọc).
enum StockState {
  inStock("Còn hàng"),
  out("Hết hàng"),
  untracked("Chưa ghi tồn");

  final String label;
  const StockState(this.label);

  static StockState of(ComponentVariant v) => v.stock == null
      ? untracked
      : v.stock! > 0
      ? inStock
      : out;
}
