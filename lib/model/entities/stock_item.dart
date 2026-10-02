import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/variant.dart';
import 'package:objectbox/objectbox.dart';

/// Tồn kho của 1 biến thể linh kiện (linh kiện không có biến thể => 1 dòng
/// với biến thể rỗng).
@Entity()
class StockItem {
  @Id()
  int id;

  /// Số lượng (cái) đang có.
  int quantity;

  /// Vị trí cất, VD "Khay 36 ngăn - B3".
  String location;

  /// Biến thể dạng JSON (xem [Variants.encodeSelection]).
  String variantJson;

  final component = ToOne<Component>();

  StockItem({
    this.id = 0,
    this.quantity = 0,
    this.location = "",
    this.variantJson = "",
  });

  VariantSelection get variant => Variants.decodeSelection(variantJson);
  set variant(VariantSelection value) =>
      variantJson = Variants.encodeSelection(value);
}
