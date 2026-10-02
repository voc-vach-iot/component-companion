import 'package:component_companion/data/stock_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/widget/common/catalog_loader.dart';
import 'package:component_companion/widget/component/component_dialog.dart';
import 'package:component_companion/widget/component/stock_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ComponentAction {
  static void showAdd(
    BuildContext context,
    WidgetRef ref, {
    ValueChanged<int>? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => CatalogLoader(
        builder: (categories, types) => ComponentDialog(
          categories: categories,
          types: types,
          onSave: (newComponent) async {
            final id =
                await ref
                    .read(componentProvider.notifier)
                    .addComponent(newComponent)
                    .withToast(context) ??
                0;
            if (context.mounted && id > 0) {
              AppSnackBar.show(
                context,
                message: "Thêm linh kiện thành công",
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
    Component component,
  ) {
    showDialog(
      context: context,
      builder: (context) => CatalogLoader(
        builder: (categories, types) => ComponentDialog(
          component: component,
          categories: categories,
          types: types,
          onSave: (updatedComponent) async {
            final id =
                await ref
                    .read(componentProvider.notifier)
                    .updateComponent(updatedComponent)
                    .withToast(context) ??
                0;
            if (context.mounted && id > 0) {
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

  /// Nhập / chỉnh tồn kho theo biến thể.
  static void showStock(
    BuildContext context,
    WidgetRef ref,
    Component component,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => StockDialog(
        component: component,
        onSave: (entries, threshold) async {
          await ref
              .read(stockRepositoryProvider)
              .saveStock(component.id, entries, lowStockThreshold: threshold)
              .withToast(context);
          if (context.mounted) {
            AppSnackBar.show(
              context,
              message: "Đã cập nhật tồn kho '${component.name}'",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }

  /// Nhân bản linh kiện (kèm toàn bộ tuỳ chọn), trả id bản sao qua [onSuccess].
  static Future<void> clone(
    BuildContext context,
    WidgetRef ref,
    Component component, {
    ValueChanged<int>? onSuccess,
  }) async {
    final id =
        await ref
            .read(componentProvider.notifier)
            .cloneComponent(component.id)
            .withToast(context) ??
        0;
    if (context.mounted && id > 0) {
      AppSnackBar.show(
        context,
        message: "Đã nhân bản '${component.name}'",
        type: SnackBarType.success,
      );
      onSuccess?.call(id);
    }
  }

  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    Component component,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa linh kiện",
        content:
            "Bạn có chắc chắn muốn xóa linh kiện '${component.name}' không? Các tùy chọn, lịch sử giá và tồn kho của nó cũng bị xoá (có thể hoàn tác ngay sau khi xoá).",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) =>
              transfer.snapshot(componentIds: [component.id]),
          delete: () => ref
              .read(componentProvider.notifier)
              .deleteComponent(component.id),
          message: "Đã xóa linh kiện '${component.name}'",
        ),
      ),
    );
  }
}
