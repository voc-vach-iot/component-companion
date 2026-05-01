import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/widget/component/component_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ComponentAction {
  static void showAdd(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        // Gói trong Consumer để đảm bảo ref.watch hoạt động đúng
        return Consumer(
          builder: (context, ref, child) {
            final categoriesAsync = ref.watch(watchAllCategoriesProvider());

            return categoriesAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => AlertDialog(content: Text("Lỗi: $err")),
              data: (categories) {
                return ComponentDialog(
                  categories: categories,
                  onSave: (newComponent) async {
                    final id = await ref
                        .read(componentProvider.notifier)
                        .addComponent(newComponent)
                        .withToast(context);
                    if (context.mounted && id != null && id > 0) {
                      AppSnackBar.show(
                        context,
                        message: "Thêm linh kiện thành công",
                        type: SnackBarType.success,
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static void showEdit(
    BuildContext context,
    WidgetRef ref,
    Component component,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        // Gói trong Consumer để đảm bảo ref.watch hoạt động đúng
        return Consumer(
          builder: (context, ref, child) {
            final categoriesAsync = ref.watch(watchAllCategoriesProvider());

            return categoriesAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => AlertDialog(content: Text("Lỗi: $err")),
              data: (categories) {
                return ComponentDialog(
                  component: component,
                  categories: categories,
                  onSave: (newComponent) async {
                    final id = await ref
                        .read(componentProvider.notifier)
                        .updateComponent(newComponent)
                        .withToast(context);
                    if (context.mounted && id != null && id > 0) {
                      AppSnackBar.show(
                        context,
                        message: "Sửa linh kiện thành công",
                        type: SnackBarType.success,
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    Component component,
  ) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDeleteDialog(
        title: "Xóa danh mục",
        content:
            "Bạn có chắc chắn muốn xóa linh kiện '${component.name}' không? Hành động này không thể hoàn tác.",
        onConfirm: () async {
          // Gọi tới Provider để thực hiện xóa trong DB
          final success =
              await ref
                  .read(componentProvider.notifier)
                  .deleteComponent(component.id)
                  .withToast(context) ??
              false;

          if (context.mounted && success) {
            AppSnackBar.show(
              context,
              message: "Đã xóa linh kiện thành công!",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }
}
