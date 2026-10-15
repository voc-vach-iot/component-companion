import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:objectbox/objectbox.dart';

/// Nhóm lựa chọn của dự án, VD "Vi điều khiển" (ESP32 | STM32) hay "Pin"
/// (1000mAh | 2000mAh). Mỗi nhóm có nhiều phương án ([ProjectOption]) và đang
/// chọn đúng 1 phương án. Cấu hình dự án = linh kiện chung + phương án đang
/// chọn của mọi nhóm => 2 nhóm x 2 phương án không cần tách thành 4 bản.
@Entity()
class ProjectGroup {
  @Id()
  int id;
  String name;

  /// Thứ tự hiển thị trong dự án (tăng dần).
  int sortOrder;

  final project = ToOne<Project>();

  /// Phương án đang dùng trong cấu hình.
  final selected = ToOne<ProjectOption>();

  @Backlink("group")
  final options = ToMany<ProjectOption>();

  ProjectGroup({this.id = 0, required this.name, this.sortOrder = 0});

  /// Phương án theo thứ tự tạo.
  List<ProjectOption> get sortedOptions =>
      options.toList()..sort((a, b) => a.id.compareTo(b.id));

  /// Phương án đang chọn (rơi về phương án đầu nếu chưa chọn / đã bị xoá).
  ProjectOption? get selectedOption {
    final list = sortedOptions;
    return list.where((o) => o.id == selected.targetId).firstOrNull ??
        list.firstOrNull;
  }

  List<ProjectItem> get selectedItems =>
      selectedOption?.items.toList() ?? const [];
}
