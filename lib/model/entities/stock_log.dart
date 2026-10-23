import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:objectbox/objectbox.dart';

/// Lý do tồn kho thay đổi.
enum StockReason {
  manual("Sửa tay"),
  stockIn("Nhập kho"),
  import("Nhập từ file / Shopee"),
  received("Nhận hàng đang về"),
  projectUse("Dùng cho dự án"),
  projectReturn("Trả lại từ dự án"),

  /// Đánh dấu đã lấy cho dự án mà không đổi tồn kho (dự án làm trước khi
  /// dùng app, kho thực tế đã thiếu sẵn). Số cái ở [StockLog.marked].
  projectMark("Đánh dấu đã dùng cho dự án"),
  merge("Gộp biến thể"),
  undo("Hoàn tác");

  final String label;
  const StockReason(this.label);

  static StockReason of(String name) =>
      values.where((r) => r.name == name).firstOrNull ?? manual;
}

/// 1 lần tồn kho của biến thể thay đổi (nhật ký kho).
@Entity()
class StockLog {
  @Id()
  int id;

  /// Tồn kho trước / sau (null = chưa theo dõi tồn kho).
  int? before;
  int? after;

  /// [StockReason.name].
  String reason;

  /// Ghi chú thêm, VD tên dự án.
  String note;

  /// [StockReason.projectMark]: số cái đánh dấu đã lấy cho dự án (âm = bỏ
  /// đánh dấu). Tồn kho không đổi.
  int marked;

  /// "Tên linh kiện · biến thể" lúc ghi — vẫn đọc được khi biến thể bị xoá.
  String label;

  @Property(type: PropertyType.date)
  DateTime at;

  final variant = ToOne<ComponentVariant>();

  /// Dự án liên quan (trừ / trả kho cho dự án).
  final project = ToOne<Project>();

  StockLog({
    this.id = 0,
    this.before,
    this.after,
    this.reason = "",
    this.note = "",
    this.marked = 0,
    this.label = "",
    DateTime? at,
  }) : at = at ?? DateTime.now();

  StockReason get stockReason => StockReason.of(reason);

  /// Số thay đổi (chưa theo dõi coi như 0).
  int get delta => (after ?? 0) - (before ?? 0);
}
