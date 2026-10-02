import 'package:component_companion/data/project_item_repository.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/service/export_service.dart';
import 'package:component_companion/service/file_service.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/notifier/project_notifier.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:component_companion/widget/project/project_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectAction {
  static void showDetail(BuildContext context, Project project) {
    context.go("/project/${project.id}");
  }

  static void showAdd(
    BuildContext context,
    WidgetRef ref, {
    ValueChanged<int>? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return ProjectDialog(
          onSave: (newProject) async {
            final id =
                await ref
                    .read(projectProvider.notifier)
                    .addProject(newProject)
                    .withToast(context) ??
                0;

            if (context.mounted && id > 0) {
              AppSnackBar.show(
                context,
                message: "Thêm dự án thành công",
                type: SnackBarType.success,
              );
              onSuccess?.call(id);
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
            final id =
                await ref
                    .read(projectProvider.notifier)
                    .updateProject(updatedProject)
                    .withToast(context) ??
                0;

            if (context.mounted && id > 0) {
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

  /// Đổi mọi linh kiện trong dự án sang tuỳ chọn rẻ nhất phù hợp biến thể.
  static Future<void> useCheapest(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final result = await ref
        .read(projectItemRepositoryProvider)
        .useCheapest(project.id)
        .withToast(context);
    if (result == null || !context.mounted) return;
    AppSnackBar.show(
      context,
      message: result.switched == 0
          ? "Tất cả linh kiện đã ở mức giá rẻ nhất"
          : "Đã đổi ${result.switched} linh kiện, tiết kiệm ${result.saving.toVND()}",
      type: SnackBarType.success,
      duration: const Duration(seconds: 4),
    );
  }

  /// Xuất BOM của dự án ra CSV.
  static Future<void> exportBom(BuildContext context, Project project) async {
    final path = await FileService.saveText(
      dialogTitle: "Lưu BOM dự án",
      fileName: "${FileService.timestamped("bom-${project.name}")}.csv",
      content: ExportService().projectBomCsv(project),
      extensions: const ["csv"],
      withBom: true,
    ).withToast(context);
    if (path != null && context.mounted) {
      AppSnackBar.show(
        context,
        message: "Đã lưu: $path",
        type: SnackBarType.success,
      );
    }
  }

  static void showDelete(BuildContext context, WidgetRef ref, Project project) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa dự án",
        content:
            "Bạn có chắc chắn muốn xóa dự án '${project.name}' không? Các phiên bản và linh kiện trong dự án cũng bị xoá (có thể hoàn tác ngay sau khi xoá).",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(projectIds: [project.id]),
          delete: () =>
              ref.read(projectProvider.notifier).deleteProject(project.id),
          message: "Đã xóa dự án '${project.name}'",
        ),
      ),
    );
  }
}
