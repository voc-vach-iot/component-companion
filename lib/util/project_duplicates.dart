import 'package:component_companion/model/entities/project_item.dart';

/// Tìm dòng linh kiện trùng trong dự án: cùng biến thể. Dòng ở cùng phần
/// (linh kiện chung / cùng 1 phương án) gộp được thành 1 dòng; ở phần khác
/// chỉ để cảnh báo (vẫn có thể cộng số lượng vào đó nếu muốn).
class ProjectDuplicates {
  ProjectDuplicates._();

  /// Phần chứa dòng: 0 = linh kiện chung, khác = id phương án.
  static int scopeOf(ProjectItem item) => item.projectOption.targetId;

  /// "Linh kiện chung" / "Nhóm › Phương án".
  static String placeOf(ProjectItem item) {
    final option = item.projectOption.target;
    if (option == null) return "Linh kiện chung";
    final group = option.group.target?.name;
    return group == null || group.isEmpty
        ? option.name
        : "$group › ${option.name}";
  }

  /// Dòng có sẵn cùng biến thể với [item] (bỏ chính nó), dòng cùng phần
  /// đứng trước.
  static List<ProjectItem> matches(
    ProjectItem item,
    Iterable<ProjectItem> existing,
  ) {
    final variantId = item.variant.targetId;
    if (variantId == 0) return const [];
    final scope = scopeOf(item);
    return [
      for (final e in existing)
        if (e.variant.targetId == variantId &&
            (item.id == 0 || e.id != item.id))
          e,
    ]..sort((a, b) {
      final sa = scopeOf(a) == scope ? 0 : 1;
      final sb = scopeOf(b) == scope ? 0 : 1;
      return sa != sb ? sa - sb : a.id - b.id;
    });
  }

  /// Các nhóm dòng trùng gộp được (cùng phần + cùng biến thể, >= 2 dòng),
  /// mỗi nhóm theo thứ tự thêm.
  static List<List<ProjectItem>> groups(Iterable<ProjectItem> items) {
    final byKey = <(int, int), List<ProjectItem>>{};
    for (final item in items) {
      if (item.variant.targetId == 0) continue;
      byKey
          .putIfAbsent((scopeOf(item), item.variant.targetId), () => [])
          .add(item);
    }
    return [
      for (final list in byKey.values)
        if (list.length > 1) list..sort((a, b) => a.id - b.id),
    ];
  }
}
