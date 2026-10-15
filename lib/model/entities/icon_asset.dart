import 'package:objectbox/objectbox.dart';

/// 1 icon trong thư viện icon (nhập từ CSV), dùng để chọn nhanh icon cho danh
/// mục, loại và linh kiện thay vì phải đi tìm SVG ở nơi khác.
@Entity()
class IconAsset {
  @Id()
  int id;
  String name;

  /// Bộ icon (thường là tên file CSV đã nhập), VD "Điện tử cơ bản".
  @Index()
  String pack;

  String svg;

  /// Từ khoá tìm kiếm thêm ngoài tên (đã chuẩn hoá lowercase).
  List<String> keywords;

  IconAsset({
    this.id = 0,
    required this.name,
    required this.svg,
    this.pack = "",
    List<String>? keywords,
  }) : keywords = keywords ?? [];
}
