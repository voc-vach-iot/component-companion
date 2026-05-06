import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/notifier/project_option_notifier.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/project/project_option_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectOptionAction {
  static void showAdd(BuildContext context, WidgetRef ref, Project project) {
    showDialog(
      context: context,
      builder: (context) => ProjectOptionDialog(
        project: project,
        onSave: (newOption) async {
          // Giả sử bạn có projectOptionNotifier
          final id =
              await ref
                  .read(projectOptionProvider.notifier)
                  .addProjectOption(newOption)
                  .withToast(context) ??
              0;
          if (context.mounted && id > 0) {
            debugPrint("Added new project option with ID: $id");
            ref.read(projectOptionEventProvider.notifier).notify();
            AppSnackBar.show(
              context,
              message: "Đã thêm phân loại!",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }

  static void showEdit(
    BuildContext context,
    WidgetRef ref,
    ProjectOption option,
  ) {
    showDialog(
      context: context,
      builder: (context) => ProjectOptionDialog(
        projectOption: option,
        onSave: (updated) async {
          final id =
              await ref
                  .read(projectOptionProvider.notifier)
                  .updateProjectOption(updated)
                  .withToast(context) ??
              0;
          if (context.mounted && id > 0) {
            debugPrint("Updated project option with ID: $id");
            ref.read(projectOptionEventProvider.notifier).notify();
            AppSnackBar.show(
              context,
              message: "Đã cập nhật phân loại!",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }

  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    ProjectOption option,
  ) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDeleteDialog(
        title: "Xóa phân loại",
        content:
            "Bạn có chắc chắn muốn xóa phân loại '${option.name}' không? Các linh kiện bên trong phân loại này cũng sẽ bị ảnh hưởng.",
        onConfirm: () async {
          // Gọi tới Provider để thực hiện xóa
          final success =
              await ref
                  .read(projectOptionProvider.notifier)
                  .deleteProjectOption(
                    option.id,
                  ) // Thay đổi tên hàm tùy theo implementation của bạn
                  .withToast(context) ??
              false;

          if (context.mounted && success) {
            ref.read(projectOptionEventProvider.notifier).notify();
            AppSnackBar.show(
              context,
              message: "Đã xóa phân loại thành công!",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }
}
