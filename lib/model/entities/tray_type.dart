import 'dart:convert';

import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:objectbox/objectbox.dart';

/// Loại khay đựng linh kiện (VD khay A6, khay F0) do người dùng tự tạo: kích
/// thước, số ngăn và màu LED nhìn rõ qua nhựa của khay.
@Entity()
class TrayType {
  @Id()
  int id;
  String name;

  /// Mặt trước rộng × sâu × cao (mm).
  double widthMm;
  double depthMm;
  double heightMm;

  /// Thanh kê giữa 2 tầng khay (mm), cộng vào chiều cao khi xếp chồng.
  double stackGapMm;

  /// Số ngăn trong khay (≥ 1). Khay có vách tháo được: số ngăn khi đủ vách
  /// (= số khe), từng khay trong kho chọn tháo vách nào.
  int compartmentCount;

  /// Vách ngăn tháo được (VD khay F0: 3 ngăn → 2 ngăn to + nhỏ, hoặc 1 ngăn).
  bool removableDividers;

  /// Các ngăn xếp theo chiều dọc (true) hay ngang (false) khi nhìn từ trước.
  bool compartmentVertical;

  /// Màu LED được phép (ARGB, JSON list). Rỗng = chọn màu thoải mái (nhựa trong).
  String allowedColorsJson;

  /// Màu LED mặc định (ARGB): khay 1 ngăn hoặc khay màu cố định.
  int defaultColor;

  /// Màu báo ngăn khi tìm linh kiện (ARGB, JSON list: ngăn 1, 2, 3…). Rỗng = [defaultCompartmentColors]. Chỉ dùng
  /// cho khay màu tự do đang chia nhiều ngăn; khay màu cố định báo ngăn bằng kiểu nháy.
  String compartmentColorsJson;

  /// Độ sáng (0–255) thấp nhất còn nhìn thấy qua nhựa / cao nhất cho phép.
  int minBrightness;
  int maxBrightness;

  String note;

  @Backlink("trayType")
  final trays = ToMany<StorageTray>();

  TrayType({
    this.id = 0,
    required this.name,
    this.widthMm = 100,
    this.depthMm = 100,
    this.heightMm = 50,
    this.stackGapMm = 0,
    this.compartmentCount = 1,
    this.compartmentVertical = false,
    this.removableDividers = false,
    this.allowedColorsJson = "",
    this.defaultColor = 0xFF0000FF,
    this.compartmentColorsJson = "",
    this.minBrightness = 40,
    this.maxBrightness = 255,
    this.note = "",
  });

  List<int> get allowedColors => allowedColorsJson.isEmpty
      ? const []
      : (jsonDecode(allowedColorsJson) as List).cast<int>();
  set allowedColors(List<int> value) =>
      allowedColorsJson = value.isEmpty ? "" : jsonEncode(value);

  /// Đỏ / xanh lá / xanh dương thuần: mỗi màu chỉ bật 1 kênh của WS2812 nên ít tốn điện nhất.
  static const defaultCompartmentColors = [0xFFFF0000, 0xFF00FF00, 0xFF0000FF];

  // Method thay vì getter / setter: cặp getter + setter bị ObjectBox coi là 1 cột
  List<int> compartmentColorList() => compartmentColorsJson.isEmpty
      ? defaultCompartmentColors
      : (jsonDecode(compartmentColorsJson) as List).cast<int>();
  void setCompartmentColors(List<int> value) =>
      compartmentColorsJson = value.isEmpty ? "" : jsonEncode(value);

  /// Màu LED khi tìm linh kiện ở ngăn [index] của khay đang chia [count] ngăn.
  int colorForCompartment(int index, int count) {
    if (isColorFixed || count <= 1) return defaultColor;
    final colors = compartmentColorList();
    return colors[(index < 0 ? 0 : index) % colors.length];
  }

  /// Chỉ được dùng các màu trong [allowedColors].
  bool get isColorFixed => allowedColors.isNotEmpty;

  /// Màu dùng được gần nhất với [color] (khay màu cố định thì ép về màu cho phép).
  int resolveColor(int? color) {
    final allowed = allowedColors;
    if (color == null) return defaultColor;
    if (allowed.isEmpty || allowed.contains(color)) return color;
    return allowed.contains(defaultColor) ? defaultColor : allowed.first;
  }
}
