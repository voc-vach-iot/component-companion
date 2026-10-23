import 'package:objectbox/objectbox.dart';

/// Nguồn cấp cho dải LED của kho (VD adapter 5V 2.4A). Độ sáng được giảm theo
/// dòng tối đa của nguồn để không quá tải.
@Entity()
class PowerSupply {
  @Id()
  int id;
  String name;
  double voltage;

  /// Dòng tối đa (A) ghi trên nguồn.
  double currentA;

  /// Chỉ dùng tối đa tỉ lệ này của [currentA] (chừa dư cho nguồn).
  double derate;

  String note;

  PowerSupply({
    this.id = 0,
    required this.name,
    this.voltage = 5,
    this.currentA = 2,
    this.derate = 0.8,
    this.note = "",
  });

  /// "5V 2.4A".
  String get spec {
    String n(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return "${n(voltage)}V ${n(currentA)}A";
  }
}
