import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/notifier/project_notifier.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/project/project_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectAction {
  static void showDetail(BuildContext context, Project project) {
    context.go("/project/${project.id}");
  }

  static void showAdd(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return ProjectDialog(
          onSave: (newProject) async {
            final id = await ref
                .read(projectProvider.notifier)
                .addProject(newProject)
                .withToast(context) ?? 0;

            if (context.mounted && id > 0) {
              ref.read(projectEventProvider.notifier).notify();
              AppSnackBar.show(
                context,
                message: "Thêm dự án thành công",
                type: SnackBarType.success,
              );
            }
          },
        );
      },
    );
  }

  static void showEdit(BuildContext context, WidgetRef ref, Project project) {
    showDialog(
      context: context,
      builder: (context) {
        return ProjectDialog(
          project: project,
          onSave: (updatedProject) async {
            final id = await ref
                .read(projectProvider.notifier)
                .updateProject(updatedProject)
                .withToast(context) ?? 0;

            if (context.mounted && id > 0) {
              ref.read(projectEventProvider.notifier).notify();
              AppSnackBar.show(
                context,
                message: "Sửa dự án thành công",
                type: SnackBarType.success,
              );
            }
          },
        );
      },
    );
  }

  static void showDelete(BuildContext context, WidgetRef ref, Project project) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDeleteDialog(
        title: "Xóa dự án",
        content:
            "Bạn có chắc chắn muốn xóa dự án '${project.name}' không? Hành động này sẽ xóa tất cả linh kiện liên quan và không thể hoàn tác.",
        onConfirm: () async {
          final success =
              await ref
                  .read(projectProvider.notifier)
                  .deleteProject(project.id)
                  .withToast(context) ??
              false;

          if (context.mounted && success) {
            ref.read(projectEventProvider.notifier).notify();
            AppSnackBar.show(
              context,
              message: "Đã xóa dự án thành công!",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }
}
