import 'package:component_companion/data/component_type_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/notifier/component_type_notifier.dart';
import 'package:component_companion/widget/common/catalog_loader.dart';
import 'package:component_companion/widget/component_type/component_type_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ComponentTypeAction {
  static String? Function(String) _keywordValidator(
    WidgetRef ref, {
    int excludeId = 0,
  }) {
    return (keyword) {
      final owner = ref
          .read(componentTypeRepositoryProvider)
          .findKeywordOwner(keyword, excludeId: excludeId);
      return owner == null ? null : "'$keyword' đã thuộc loại '${owner.name}'";
    };
  }

  static void showAdd(
    BuildContext context,
    WidgetRef ref, {
    ValueChanged<int>? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => CatalogLoader(
        builder: (categories, _) => ComponentTypeDialog(
          categories: categories,
          keywordValidator: _keywordValidator(ref),
          onSave: (newType) async {
            final id =
                await ref
                    .read(componentTypeProvider.notifier)
                    .addComponentType(newType)
                    .withToast(context) ??
                0;

            if (context.mounted && id > 0) {
              AppSnackBar.show(
                context,
                message: "Đã thêm loại linh kiện thành công!",
                type: SnackBarType.success,
              );
              onSuccess?.call(id);
            }
          },
        ),
      ),
    );
  }

  static void showEdit(
    BuildContext context,
    WidgetRef ref,
    ComponentType type,
  ) {
    showDialog(
      context: context,
      builder: (context) => CatalogLoader(
        builder: (categories, _) => ComponentTypeDialog(
          type: type,
          categories: categories,
          keywordValidator: _keywordValidator(ref, excludeId: type.id),
          onSave: (updatedType) async {
            final id =
                await ref
                    .read(componentTypeProvider.notifier)
                    .updateComponentType(updatedType)
                    .withToast(context) ??
                0;

            if (context.mounted && id > 0) {
              AppSnackBar.show(
                context,
                message: "Đã cập nhật loại linh kiện thành công!",
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
    ComponentType type,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa loại linh kiện",
        content:
            "Bạn có chắc chắn muốn xóa loại '${type.name}' không? Các linh kiện thuộc loại này sẽ mất icon mặc định.",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(typeIds: [type.id]),
          delete: () => ref
              .read(componentTypeProvider.notifier)
              .deleteComponentType(type.id),
          message: "Đã xóa loại '${type.name}'",
        ),
      ),
    );
  }
}
