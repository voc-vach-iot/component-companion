import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/data/category_repository.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/widget/category/category_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
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
    ValueChanged<int>? onSuccess,
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

            onSuccess?.call(id);
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
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa danh mục",
        content:
            "Bạn có chắc chắn muốn xóa danh mục '${category.name}' không? Các linh kiện thuộc danh mục sẽ thành 'Chưa phân loại' (có thể hoàn tác ngay sau khi xoá).",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(categoryIds: [category.id]),
          delete: () =>
              ref.read(categoryProvider.notifier).deleteCategory(category.id),
          message: "Đã xóa danh mục '${category.name}'",
        ),
      ),
    );
  }
}
