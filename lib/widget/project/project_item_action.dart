import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/notifier/project_item_notifier.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/project/project_item_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectItemAction {
  static void showAdd(
    BuildContext context,
    WidgetRef ref, {
    Project? project,
    ProjectOption? projectOption,
    VoidCallback? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => ComponentLoader(
        // ComponentLoader lấy từ watchAllComponentsProvider
        builder: (availableComponents) => ProjectItemDialog(
          project: project,
          projectOption: projectOption,
          availableComponents: availableComponents,
          onSave: (newItem) async {
            final id =
                await ref
                    .read(projectItemProvider.notifier)
                    .addProjectItem(newItem)
                    .withToast(context) ??
                0;
            if (context.mounted && id > 0) {
              ref
                  .read(projectItemEventProvider.notifier)
                  .notify(); // Thông báo cập nhật
              AppSnackBar.show(
                context,
                message: "Đã thêm linh kiện",
                type: SnackBarType.success,
              );
              onSuccess?.call();
            }
          },
        ),
      ),
    );
  }

  static void showEdit(
    BuildContext context,
    WidgetRef ref, {
    required ProjectItem item,
  }) {
    showDialog(
      context: context,
      builder: (context) => ComponentLoader(
        builder: (availableComponents) => ProjectItemDialog(
          projectItem: item,
          availableComponents: availableComponents,
          onSave: (updatedItem) async {
            final id =
                await ref
                    .read(projectItemProvider.notifier)
                    .updateProjectItem(updatedItem)
                    .withToast(context) ??
                0;

            if (context.mounted && id > 0) {
              ref
                  .read(projectItemEventProvider.notifier)
                  .notify(); // Thông báo cập nhật
              AppSnackBar.show(
                context,
                message: "Đã cập nhật",
                type: SnackBarType.success,
              );
            }
          },
        ),
      ),
    );
  }

  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    ProjectItem item,
  ) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDeleteDialog(
        title: "Xóa linh kiện",
        content: "Bạn có chắc chắn muốn xóa linh kiện này khỏi dự án không?",
        onConfirm: () async {
          final success =
              await ref
                  .read(projectItemProvider.notifier)
                  .deleteProjectItem(item.id)
                  .withToast(context) ??
              false;

          if (context.mounted && success) {
            ref
                .read(projectItemEventProvider.notifier)
                .notify(); // Thông báo cập nhật
            AppSnackBar.show(
              context,
              message: "Đã xóa linh kiện",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }
}

// Helper widget để load dữ liệu trước khi hiện Dialog
class ComponentLoader extends ConsumerWidget {
  final Widget Function(List<Component> components) builder;

  const ComponentLoader({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final componentsAsync = ref.watch(watchAllComponentsProvider());

    return componentsAsync.when(
      loading: () => const AppLoadingView(),
      error: (err, _) => AppErrorView(message: "Lỗi khi tải linh kiện: $err"),
      data: (components) {
        // --- XỬ LÝ DANH SÁCH RỖNG ---
        if (components.isEmpty) {
          return AlertDialog(
            title: const Text("Thông báo"),
            content: const Text(
              "Chưa có linh kiện nào trong hệ thống. Vui lòng thêm linh kiện trước.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Đóng"),
              ),
            ],
          );
        }
        return builder(components);
      },
    );
  }
}
