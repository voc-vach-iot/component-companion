import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:objectbox/objectbox.dart';

/// Kho (kệ / tủ) nhìn từ mặt trước, các khay được kéo thả lên đó. Mỗi kho có
/// 1 bộ điều khiển LED (ESP32-C3 + CH32V003) và 1 dải WS2812, mỗi khay 1 LED.
@Entity()
class Storage {
  @Id()
  int id;
  String name;

  /// Kích thước mặt trước (mm) và bước bắt dính khi kéo thả.
  double widthMm;
  double heightMm;
  double gridMm;

  /// Số LED trên dải.
  int ledCount;

  /// Thứ tự byte màu của LED ("GRB" với WS2812B).
  String colorOrder;

  /// Dòng mỗi kênh màu ở độ sáng tối đa (mA), dòng mỗi LED khi tắt (mA), dòng
  /// của mạch điều khiển (mA) — dùng để giới hạn độ sáng theo nguồn.
  double mAPerChannel;
  double idleMaPerLed;
  double mcuMa;

  /// Tự tắt LED sau số giây này.
  int lightTimeoutS;

  /// Thiết bị BLE đã ghép (rỗng = chưa ghép, chỉ giả lập).
  String bleDeviceId;
  String bleName;

  String note;

  final powerSupply = ToOne<PowerSupply>();

  @Backlink("storage")
  final trays = ToMany<StorageTray>();

  Storage({
    this.id = 0,
    required this.name,
    this.widthMm = 1000,
    this.heightMm = 800,
    this.gridMm = 10,
    this.ledCount = 60,
    this.colorOrder = "GRB",
    this.mAPerChannel = 20,
    this.idleMaPerLed = 0.6,
    this.mcuMa = 120,
    this.lightTimeoutS = 60,
    this.bleDeviceId = "",
    this.bleName = "",
    this.note = "",
  });
}
