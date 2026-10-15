import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';

/// 1 lần linh kiện được dùng trong dự án.
typedef ProjectUsage = ({
  Project project,
  ProjectItem item,

  /// "Chung" hoặc "Nhóm: Phương án".
  String place,

  /// Thuộc cấu hình đang chọn của dự án (phần chung / phương án đang chọn).
  bool active,
});

class ProjectUsages {
  ProjectUsages._();

  static List<ProjectUsage> of(Component component) {
    final result = <ProjectUsage>[];
    for (final item in component.projectItem) {
      final base = item.project.target;
      if (base != null) {
        result.add((project: base, item: item, place: "Chung", active: true));
        continue;
      }
      final option = item.projectOption.target;
      final group = option?.group.target;
      final project = option?.project.target ?? group?.project.target;
      if (option == null || project == null) continue;
      result.add((
        project: project,
        item: item,
        place: group == null ? option.name : "${group.name}: ${option.name}",
        active: group?.selectedOption?.id == option.id,
      ));
    }
    result.sort((a, b) {
      final byProject = a.project.name.toLowerCase().compareTo(
        b.project.name.toLowerCase(),
      );
      return byProject != 0 ? byProject : a.place.compareTo(b.place);
    });
    return result;
  }

  /// Tên các dự án (không trùng) đang dùng linh kiện.
  static List<String> projectNames(Component component) =>
      {for (final u in of(component)) u.project.name}.toList();
}
