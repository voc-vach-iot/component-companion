import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/unit.dart';
import 'package:component_companion/service/bulk_edit_service.dart';
import 'package:component_companion/widget/notification/bulk_undo_toast.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/widget/common/catalog_loader.dart';
import 'package:component_companion/widget/component/component_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:component_companion/util/project_usage.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ComponentAction {
  /// Thêm linh kiện, trả về id mới (null nếu huỷ / lỗi). [initialName] = tên
  /// điền sẵn.
  static Future<int?> showAdd(
    BuildContext context,
    WidgetRef ref, {
    String initialName = "",
    ValueChanged<int>? onSuccess,
  }) async {
    int? createdId;
    await showDialog(
      context: context,
      builder: (dialogContext) => CatalogLoader(
        builder: (categories, types) => ComponentDialog(
          categories: categories,
          types: types,
          initialName: initialName,
          onSave: (newComponent, _) async {
            final id =
                await ref
                    .read(componentProvider.notifier)
                    .addComponent(newComponent)
                    .withToast(dialogContext) ??
                0;
            if (id <= 0) return false;
            if (context.mounted) {
              AppSnackBar.show(
                context,
                message: "Thêm linh kiện thành công",
                type: SnackBarType.success,
              );
            }
            createdId = id;
            onSuccess?.call(id);
            return true;
          },
        ),
      ),
    );
    return createdId;
  }

  static void showEdit(BuildContext context, WidgetRef ref, Component shown) {
    // Sửa trên bản đọc mới để huỷ / lỗi không làm bẩn dữ liệu đang hiển thị
    final component = ref.read(componentRepositoryProvider).get(shown.id);
    if (component == null) return;
    final oldUnit = component.unit;
    showDialog(
      context: context,
      builder: (dialogContext) => CatalogLoader(
        builder: (categories, types) => ComponentDialog(
          component: component,
          categories: categories,
          types: types,
          onSave: (updatedComponent, renames) async {
            // Đổi đơn vị là bước riêng (quy đổi số lưu, có hoàn tác)
            final newUnit = updatedComponent.unit;
            updatedComponent.unit = oldUnit;
            final id =
                await ref
                    .read(componentProvider.notifier)
                    .updateComponent(updatedComponent, renames: renames)
                    .withToast(dialogContext) ??
                0;
            if (id <= 0) return false;
            if (!context.mounted) return true;
            if (newUnit == oldUnit) {
              AppSnackBar.show(
                context,
                message: "Cập nhật linh kiện thành công",
                type: SnackBarType.success,
              );
              return true;
            }
            final undo = BulkEditService().changeUnit([
              id,
            ], QuantityUnit.of(newUnit));
            BulkUndoToast.show(
              context,
              message:
                  "Đã đổi đơn vị '${updatedComponent.name}' sang ${QuantityUnit.of(newUnit).label}",
              undo: undo,
            );
            return true;
          },
        ),
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
    final usedIn = ProjectUsages.projectNames(component);
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa linh kiện",
        content:
            "Bạn có chắc chắn muốn xóa linh kiện '${component.name}' không? Các biến thể, tồn kho, tùy chọn mua và lịch sử giá của nó cũng bị xoá (có thể hoàn tác ngay sau khi xoá)."
            "${usedIn.isEmpty ? "" : "\n\n⚠ Đang dùng trong ${usedIn.length} dự án: ${usedIn.take(5).join(", ")}${usedIn.length > 5 ? "…" : ""}. Các dòng này sẽ thành linh kiện đã xoá."}",
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
