import 'package:component_companion/model/entities/component_option.dart';
import 'package:objectbox/objectbox.dart';

/// Lịch sử giá của một tuỳ chọn mua hàng. Ghi lại mỗi khi giá/quy cách đổi
/// hoặc khi người dùng xác nhận "giá vẫn vậy".
@Entity()
class PriceRecord {
  @Id()
  int id;
  int pricePerPack;
  int unitsPerPack;

  @Property(type: PropertyType.date)
  DateTime recordedAt;

  final option = ToOne<ComponentOption>();

  PriceRecord({
    this.id = 0,
    required this.pricePerPack,
    required this.unitsPerPack,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  double get pricePerUnit =>
      unitsPerPack <= 0 ? pricePerPack.toDouble() : pricePerPack / unitsPerPack;
}
