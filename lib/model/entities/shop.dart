import 'package:component_companion/model/entities/component_option.dart';
import 'package:objectbox/objectbox.dart';

/// Shop / nhà bán. Tuỳ chọn mua hàng tham chiếu tới shop nên đổi tên 1 chỗ
/// là cập nhật mọi nơi.
@Entity()
class Shop {
  @Id()
  int id;
  String name;

  /// Link trang shop (Shopee, Lazada, website...).
  String link;
  String note;

  @Backlink("shop")
  final options = ToMany<ComponentOption>();

  Shop({this.id = 0, required this.name, this.link = "", this.note = ""});
}
