import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/variant.dart';
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
  /// Thêm biến thể, trả về id biến thể mới (null nếu huỷ / lỗi).
  static Future<int?> showAdd(
    BuildContext context,
    WidgetRef ref,
    Component component, {
    ValueChanged<int>? onSuccess,
  }) async {
    int? createdId;
    await showDialog(
      context: context,
      builder: (dialogContext) => VariantDialog(
        component: component,
        onSave: (variant) async {
          final ok = await _addMissingValues(
            dialogContext,
            ref,
            component,
            variant,
          );
          if (!ok || !dialogContext.mounted) return false;
          final id =
              await ref
                  .read(variantProvider.notifier)
                  .addVariant(variant)
                  .withToast(dialogContext) ??
              0;
          if (id <= 0) return false;
          createdId = id;
          onSuccess?.call(id);
          return true;
        },
      ),
    );
    return createdId;
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
          final ok = await _addMissingValues(
            dialogContext,
            ref,
            component,
            next,
          );
          if (!ok || !dialogContext.mounted) return false;
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

  /// Giá trị gõ mới trong dialog biến thể => thêm vào thuộc tính của linh kiện
  /// trước khi lưu biến thể.
  static Future<bool> _addMissingValues(
    BuildContext context,
    WidgetRef ref,
    Component component,
    ComponentVariant variant,
  ) async {
    final repo = ref.read(componentRepositoryProvider);
    final fresh = repo.get(component.id);
    if (fresh == null) return false;
    final selection = variant.selection;
    var changed = false;
    final attributes = <VariantAttribute>[];
    for (final a in fresh.attributes) {
      final value = selection[a.name];
      if (value != null && !a.values.contains(value)) {
        changed = true;
        attributes.add(VariantAttribute(a.name, [...a.values, value]));
      } else {
        attributes.add(a);
      }
    }
    if (!changed) return true;
    fresh.attributes = attributes;
    final id = await repo.update(fresh).withToast(context) ?? 0;
    return id > 0;
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
