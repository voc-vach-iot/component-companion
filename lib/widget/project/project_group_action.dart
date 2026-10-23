import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/notifier/project_group_notifier.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:component_companion/widget/project/project_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectGroupAction {
  static void showAdd(
    BuildContext context,
    WidgetRef ref,
    Project project, {
    ValueChanged<int>? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => ProjectGroupDialog(
        onSave: (name, optionNames) async {
          final group = ProjectGroup(name: name)..project.targetId = project.id;
          final id =
              await ref
                  .read(projectGroupProvider.notifier)
                  .addGroup(group, optionNames)
                  .withToast(dialogContext) ??
              0;
          if (id <= 0) return false;
          onSuccess?.call(id);
          if (context.mounted) {
            AppSnackBar.show(
              context,
              message: "Đã thêm nhóm '$name'",
              type: SnackBarType.success,
            );
          }
          return true;
        },
      ),
    );
  }

  static void showEdit(
    BuildContext context,
    WidgetRef ref,
    ProjectGroup group,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ProjectGroupDialog(
        group: group,
        onSave: (name, _) async {
          final id =
              await ref
                  .read(projectGroupProvider.notifier)
                  .updateGroup(ProjectGroup(id: group.id, name: name))
                  .withToast(dialogContext) ??
              0;
          return id > 0;
        },
      ),
    );
  }

  static Future<void> move(
    BuildContext context,
    WidgetRef ref,
    ProjectGroup group,
    int delta,
  ) => ref
      .read(projectGroupProvider.notifier)
      .move(group.id, delta)
      .withToast(context);

  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    ProjectGroup group,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa nhóm lựa chọn",
        content:
            "Xoá nhóm '${group.name}' cùng ${group.options.length} phương án và "
            "linh kiện bên trong? (có thể hoàn tác ngay sau khi xoá)",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) =>
              transfer.snapshot(projectGroupIds: [group.id]),
          delete: () =>
              ref.read(projectGroupProvider.notifier).deleteGroup(group.id),
          message: "Đã xóa nhóm '${group.name}'",
        ),
      ),
    );
  }
}
