import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/util/compartments.dart';
import 'package:objectbox/objectbox.dart';

/// 1 khay đặt trong kho. Mỗi khay có tối đa 1 LED ([ledIndex]); các ngăn của
/// khay dùng chung LED đó.
@Entity()
class StorageTray {
  @Id()
  int id;

  /// Góc trên-trái trên mặt trước của kho (mm).
  double xMm;
  double yMm;

  /// Xoay 90°: mặt trước là cạnh sâu thay vì cạnh rộng.
  bool rotated;

  /// Tên ngắn in trên khay, VD "A1".
  String label;

  /// Vị trí LED trên dải (0 = LED đầu tiên), -1 = chưa gắn LED.
  int ledIndex;

  /// Vách đã tháo (mặt nạ bit, xem [Compartments]); 0 = đủ vách.
  int removedDividers;

  final storage = ToOne<Storage>();
  final trayType = ToOne<TrayType>();

  @Backlink("tray")
  final variants = ToMany<ComponentVariant>();

  StorageTray({
    this.id = 0,
    this.xMm = 0,
    this.yMm = 0,
    this.rotated = false,
    this.label = "",
    this.ledIndex = -1,
    this.removedDividers = 0,
  });

  bool get hasLed => ledIndex >= 0;

  /// Chiều rộng mặt trước (mm).
  double get frontWidthMm {
    final t = trayType.target;
    if (t == null) return 50;
    return rotated ? t.depthMm : t.widthMm;
  }

  /// Chiều cao chiếm chỗ (mm), gồm cả thanh kê phía trên.
  double get frontHeightMm {
    final t = trayType.target;
    if (t == null) return 50;
    return t.heightMm + t.stackGapMm;
  }

  /// Số khe (= số ngăn khi đủ vách).
  int get slotCount => trayType.target?.compartmentCount ?? 1;

  /// Vách đang tháo (bỏ qua nếu loại khay không cho tháo vách).
  int get activeRemovedDividers =>
      trayType.target?.removableDividers == true ? removedDividers : 0;

  /// Số khe của từng ngăn, VD [2, 1] = ngăn to + ngăn nhỏ.
  List<int> compartmentSizes() =>
      Compartments.sizes(slotCount, activeRemovedDividers);

  int get compartmentCount => compartmentSizes().length;

  /// "A1" hoặc "A1 / ngăn 2" (khay nhiều ngăn).
  String compartmentLabel(int index) {
    final name = label.isEmpty ? "Khay #$id" : label;
    final sizes = compartmentSizes();
    if (sizes.length <= 1) return name;
    final big = sizes.reduce((a, b) => a > b ? a : b);
    final mixed = sizes.any((s) => s != big);
    final size = !mixed || index >= sizes.length
        ? ""
        : sizes[index] == big
        ? " (to)"
        : " (nhỏ)";
    return "$name / ngăn ${index + 1}$size";
  }
}
