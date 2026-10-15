import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/notifier/project_group_notifier.dart';
import 'package:component_companion/notifier/project_option_notifier.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:component_companion/widget/project/project_option_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Thao tác với phương án trong nhóm lựa chọn của dự án.
class ProjectOptionAction {
  /// Thêm phương án; [onSuccess] nhận id phương án mới.
  static void showAdd(
    BuildContext context,
    WidgetRef ref,
    ProjectGroup group, {
    ValueChanged<int>? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => ProjectOptionDialog(
        group: group,
        onSave: (option) async {
          final id =
              await ref
                  .read(projectOptionProvider.notifier)
                  .addProjectOption(option)
                  .withToast(dialogContext) ??
              0;
          if (id <= 0) return false;
          onSuccess?.call(id);
          return true;
        },
      ),
    );
  }

  static void showEdit(
    BuildContext context,
    WidgetRef ref,
    ProjectGroup group,
    ProjectOption option,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ProjectOptionDialog(
        group: group,
        projectOption: option,
        onSave: (updated) async {
          final id =
              await ref
                  .read(projectOptionProvider.notifier)
                  .updateProjectOption(updated)
                  .withToast(dialogContext) ??
              0;
          return id > 0;
        },
      ),
    );
  }

  /// Dùng phương án này trong cấu hình dự án.
  static Future<void> select(
    BuildContext context,
    WidgetRef ref,
    ProjectOption option,
  ) => ref
      .read(projectGroupProvider.notifier)
      .select(option.id)
      .withToast(context);

  /// Nhân bản phương án kèm linh kiện rồi chuyển sang dùng bản sao.
  static Future<void> duplicate(
    BuildContext context,
    WidgetRef ref,
    ProjectOption option,
  ) async {
    final id =
        await ref
            .read(projectOptionProvider.notifier)
            .duplicateProjectOption(option.id)
            .withToast(context) ??
        0;
    if (id <= 0 || !context.mounted) return;
    await ref.read(projectGroupProvider.notifier).select(id).withToast(context);
    if (context.mounted) {
      AppSnackBar.show(
        context,
        message:
            "Đã nhân bản '${option.name}' kèm ${option.items.length} linh kiện",
        type: SnackBarType.success,
      );
    }
  }

  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    ProjectOption option,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa phương án",
        content:
            "Xoá phương án '${option.name}' cùng ${option.items.length} linh kiện "
            "bên trong? (có thể hoàn tác ngay sau khi xoá)",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) =>
              transfer.snapshot(projectOptionIds: [option.id]),
          delete: () => ref
              .read(projectOptionProvider.notifier)
              .deleteProjectOption(option.id),
          message: "Đã xóa phương án '${option.name}'",
        ),
      ),
    );
  }
}
