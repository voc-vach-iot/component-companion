import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/component/component_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ComponentAction {
  static void showAdd(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => CategoryLoader(
        builder: (categories) => ComponentDialog(
          categories: categories,
          onSave: (newComponent) async {
            final id =
                await ref
                    .read(componentProvider.notifier)
                    .addComponent(newComponent)
                    .withToast(context) ??
                0;
            if (context.mounted && id > 0) {
              ref.read(componentEventProvider.notifier).notify();
              AppSnackBar.show(
                context,
                message: "Thêm linh kiện thành công",
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
    WidgetRef ref,
    Component component,
  ) {
    showDialog(
      context: context,
      builder: (context) => CategoryLoader(
        builder: (categories) => ComponentDialog(
          component: component,
          categories: categories,
          onSave: (updatedComponent) async {
            final id =
                await ref
                    .read(componentProvider.notifier)
                    .updateComponent(updatedComponent)
                    .withToast(context) ??
                0;
            if (context.mounted && id > 0) {
              ref.read(componentEventProvider.notifier).notify();
              AppSnackBar.show(
                context,
                message: "Cập nhật linh kiện thành công",
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
            ref.read(componentEventProvider.notifier).notify();
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

class CategoryLoader extends StatelessWidget {
  final Widget Function(List<Category> categories) builder;

  const CategoryLoader({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final categoriesAsync = ref.watch(watchAllCategoriesProvider());
        return categoriesAsync.when(
          loading: () => const AppLoadingView(),
          error: (err, _) =>
              AppErrorView(message: "Lỗi khi tải danh mục: $err"),
          data: builder,
        );
      },
    );
  }
}
