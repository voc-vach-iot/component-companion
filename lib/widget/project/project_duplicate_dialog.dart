import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/project_duplicates.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Báo linh kiện sắp thêm đã có trong dự án (cùng biến thể): ở đâu, bao
/// nhiêu cái, mua ở đâu. Mỗi dòng trùng chọn gộp vào 1 dòng có sẵn (cộng số
/// lượng) hoặc thêm thành dòng mới.
///
/// Trả về chỉ số dòng mới => id dòng có sẵn để gộp (thiếu = thêm mới), null
/// = huỷ thêm.
class ProjectDuplicateDialog extends HookWidget {
  final List<ProjectItem> items;

  /// Dòng có sẵn trùng với từng dòng trong [items] (cùng thứ tự).
  final List<List<ProjectItem>> matches;

  const ProjectDuplicateDialog({
    super.key,
    required this.items,
    required this.matches,
  });

  static Future<Map<int, int>?> show(
    BuildContext context, {
    required List<ProjectItem> items,
    required List<List<ProjectItem>> matches,
  }) => showDialog<Map<int, int>>(
    context: context,
    builder: (_) => ProjectDuplicateDialog(items: items, matches: matches),
  );

  /// Nơi dòng mới sẽ được thêm vào (dòng chưa lưu nên đọc phương án từ DB).
  static String _newPlace(ProjectItem item) {
    final id = item.projectOption.targetId;
    final option = id == 0
        ? null
        : ObjectboxService.instance.get<ProjectOption>().get(id);
    if (option == null) return "Linh kiện chung";
    final group = option.group.target?.name;
    return group == null || group.isEmpty
        ? option.name
        : "$group › ${option.name}";
  }

  @override
  Widget build(BuildContext context) {
    final variants = ObjectboxService.instance.get<ComponentVariant>();
    // Mặc định gộp vào dòng trùng đầu tiên (cùng phần đứng trước)
    final choice = useState<Map<int, int>>({
      for (var i = 0; i < items.length; i++)
        if (matches[i].isNotEmpty) i: matches[i].first.id,
    });
    final duplicated = [
      for (var i = 0; i < items.length; i++)
        if (matches[i].isNotEmpty) i,
    ];
    final mergeCount = choice.value.length;
    final addCount = items.length - mergeCount;

    void pick(int index, int? targetId) => choice.value = {
      for (final e in choice.value.entries)
        if (e.key != index) e.key: e.value,
      index: ?targetId,
    };

    Widget optionTile({
      required bool selected,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
    }) => ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 8),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppColors.textMuted,
        size: 20,
      ),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );

    Widget block(int i) {
      final item = items[i];
      final label =
          variants.get(item.variant.targetId)?.fullLabel ?? "Linh kiện";
      final target = choice.value[i];
      // Material (không phải Container màu) để ListTile vẽ được hiệu ứng bấm
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$label — thêm ${item.quantity} cái vào ${_newPlace(item)}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  "Đã có ${matches[i].length} dòng cùng biến thể:",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                for (final m in matches[i])
                  optionTile(
                    selected: target == m.id,
                    title:
                        "Gộp vào ${ProjectDuplicates.placeOf(m)}: đang ${m.quantity}"
                        " cái → ${m.quantity + item.quantity} cái",
                    subtitle: [
                      if (m.componentOption.target case final o?)
                        "Mua ở: ${o.displayName}",
                      if (ProjectDuplicates.scopeOf(m) !=
                          ProjectDuplicates.scopeOf(item))
                        "Khác phần đang thêm",
                    ].join(" · "),
                    onTap: () => pick(i, m.id),
                  ),
                optionTile(
                  selected: target == null,
                  title: "Vẫn thêm thành dòng mới",
                  onTap: () => pick(i, null),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppAlertDialog(
      title: "Linh kiện đã có trong dự án",
      size: AlertDialogSize.big,
      cancelLabel: "Huỷ thêm",
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (items.length > duplicated.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "${items.length - duplicated.length} linh kiện khác không "
                    "trùng sẽ được thêm như bình thường.",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              for (final i in duplicated) block(i),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: [
            if (mergeCount > 0) "Gộp $mergeCount",
            if (addCount > 0) "Thêm mới $addCount",
          ].join(" · "),
          size: ButtonSize.small,
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.pop(context, choice.value),
        ),
      ],
    );
  }
}
