import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/data/category_repository.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/widget/category/category_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryAction {
  static String? Function(String) _keywordValidator(
    WidgetRef ref, {
    int excludeId = 0,
  }) {
    return (keyword) {
      final owner = ref
          .read(categoryRepositoryProvider)
          .findKeywordOwner(keyword, excludeId: excludeId);
      return owner == null
          ? null
          : "'$keyword' đã thuộc danh mục '${owner.name}'";
    };
  }

  static void showAdd(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(
        keywordValidator: _keywordValidator(ref),
        onSave: (newCategory) async {
          // Gọi notifier để thêm vào DB
          final id =
              await ref
                  .read(categoryProvider.notifier)
                  .addCategory(newCategory)
                  .withToast(context) ??
              0;

          // Không cần làm gì thêm, vì stream watchCategoriesProvider
          if (context.mounted && id > 0) {
            AppSnackBar.show(
              context,
              message: "Đã thêm danh mục thành công!",
              type: SnackBarType.success,
            );

            onSuccess?.call();
          }
        },
      ),
    );
  }

  static void showEdit(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(
        category: category,
        keywordValidator: _keywordValidator(ref, excludeId: category.id),
        onSave: (updatedCategory) async {
          final id =
              await ref
                  .read(categoryProvider.notifier)
                  .updateCategory(updatedCategory)
                  .withToast(context) ??
              0;

          if (context.mounted && id > 0) {
            AppSnackBar.show(
              context,
              message: "Đã cập nhật danh mục thành công!",
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
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDeleteDialog(
        title: "Xóa danh mục",
        content:
            "Bạn có chắc chắn muốn xóa danh mục '${category.name}' không? Hành động này không thể hoàn tác.",
        onConfirm: () async {
          // Gọi tới Provider để thực hiện xóa trong DB
          final success =
              await ref
                  .read(categoryProvider.notifier)
                  .deleteCategory(category.id)
                  .withToast(context) ??
              false;

          if (context.mounted && success) {
            AppSnackBar.show(
              context,
              message: "Đã xóa danh mục thành công!",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }
}
