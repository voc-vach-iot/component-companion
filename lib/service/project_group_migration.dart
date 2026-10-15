import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Trước khi có nhóm lựa chọn, mỗi "phiên bản" của dự án là 1 bộ linh kiện
/// thay thế lẫn nhau. Chuyển các phiên bản chưa thuộc nhóm nào vào nhóm
/// [legacyGroupName] của dự án (giữ nguyên ý nghĩa: chọn 1 trong các bản).
///
/// An toàn khi chạy lại: chỉ xử lý phương án chưa có nhóm, và sửa nhóm đang
/// trỏ tới phương án đã bị xoá.
class ProjectGroupMigration {
  static const legacyGroupName = "Phiên bản";

  final _db = ObjectboxService.instance;

  /// Chạy trong transaction riêng.
  void runInTransaction() {
    final changed = _db.store.runInTransaction(TxMode.write, run);
    if (changed > 0) {
      debugPrint("🔄 Đã gom $changed phiên bản vào nhóm lựa chọn");
    }
  }

  /// Trả về số phương án đã gom vào nhóm (gọi trong transaction).
  int run() {
    final optionBox = _db.get<ProjectOption>();
    final groupBox = _db.get<ProjectGroup>();

    final orphans = optionBox
        .query(ProjectOption_.group.equals(0))
        .findAndClose()
        .where((o) => o.project.targetId != 0)
        .toList();
    final byProject = <int, List<ProjectOption>>{};
    for (final o in orphans) {
      (byProject[o.project.targetId] ??= []).add(o);
    }

    for (final MapEntry(key: projectId, value: options) in byProject.entries) {
      options.sort((a, b) => a.id.compareTo(b.id));
      final groups = groupBox
          .query(ProjectGroup_.project.equals(projectId))
          .findAndClose();
      final group =
          groups.where((g) => g.name == legacyGroupName).firstOrNull ??
          (ProjectGroup(
            name: legacyGroupName,
            sortOrder:
                groups.fold(-1, (m, g) => g.sortOrder > m ? g.sortOrder : m) +
                1,
          )..project.targetId = projectId);
      final groupId = groupBox.put(group);
      for (final o in options) {
        o.group.targetId = groupId;
      }
      optionBox.putMany(options);
    }

    // Nhóm chưa chọn / chọn phương án không còn => chọn phương án đầu
    final groups = groupBox.getAll();
    final fixed = <ProjectGroup>[];
    for (final g in groups) {
      final ids = g.options.map((o) => o.id).toList()..sort();
      if (ids.isEmpty || ids.contains(g.selected.targetId)) continue;
      g.selected.targetId = ids.first;
      fixed.add(g);
    }
    groupBox.putMany(fixed);

    return orphans.length;
  }
}
