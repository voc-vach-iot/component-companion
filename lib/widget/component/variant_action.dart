import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/notifier/variant_notifier.dart';
import 'package:component_companion/widget/component/variant_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class VariantAction {
  static void showAdd(
    BuildContext context,
    WidgetRef ref,
    Component component, {
    ValueChanged<int>? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => VariantDialog(
        component: component,
        onSave: (variant) async {
          final id =
              await ref
                  .read(variantProvider.notifier)
                  .addVariant(variant)
                  .withToast(dialogContext) ??
              0;
          if (id > 0) onSuccess?.call(id);
          return id > 0;
        },
      ),
    );
  }

  static void showEdit(
    BuildContext context,
    WidgetRef ref,
    Component component,
    ComponentVariant variant,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => VariantDialog(
        component: component,
        variant: variant,
        onSave: (next) async {
          final id =
              await ref
                  .read(variantProvider.notifier)
                  .updateVariant(next)
                  .withToast(dialogContext) ??
              0;
          return id > 0;
        },
      ),
    );
  }

  static void showBulkAdd(
    BuildContext context,
    WidgetRef ref,
    Component component,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => VariantBulkDialog(
        component: component,
        onSave: (selections) async {
          final count = await ref
              .read(variantProvider.notifier)
              .addVariants(
                component.id,
                selections,
                lowStockThreshold: component.lowStockThreshold,
              )
              .withToast(dialogContext);
          if (count == null) return false;
          if (context.mounted) {
            AppSnackBar.show(
              context,
              message: "Đã tạo $count biến thể",
              type: SnackBarType.success,
            );
          }
          return true;
        },
      ),
    );
  }

  static Future<void> adjustStock(
    BuildContext context,
    WidgetRef ref,
    ComponentVariant variant,
    int delta,
  ) async {
    await ref
        .read(variantProvider.notifier)
        .adjustStock(variant.id, delta)
        .withToast(context);
  }

  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    ComponentVariant variant,
  ) {
    final label = variant.label;
    final usedIn = variant.projectItems.length;
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa biến thể",
        content:
            "Xoá biến thể '$label'? Tồn kho của biến thể bị xoá, tuỳ chọn mua "
            "chỉ gỡ khỏi biến thể này"
            "${usedIn > 0 ? ", $usedIn linh kiện trong dự án sẽ thành chưa chọn biến thể" : ""}.",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(variantIds: [variant.id]),
          delete: () =>
              ref.read(variantProvider.notifier).deleteVariant(variant.id),
          message: "Đã xóa biến thể '$label'",
        ),
      ),
    );
  }
}
