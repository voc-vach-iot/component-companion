import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/notifier/component_option_notifier.dart';
import 'package:component_companion/widget/component/component_option_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ComponentOptionAction {
  // Thêm Option
  static void showAdd(
    BuildContext context,
    WidgetRef ref,
    Component component, {
    VoidCallback? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => ComponentOptionDialog(
        component: component,
        onSave: (newOption) async {
          final id =
              await ref
                  .read(
                    componentOptionProvider.notifier,
                  ) // Thay bằng provider quản lý option
                  .addComponentOption(newOption)
                  .withToast(context) ??
              0;

          if (context.mounted && id > 0) {
            ref.read(componentOptionEventProvider.notifier).notify();
            AppSnackBar.show(
              context,
              message: "Thêm tùy chọn thành công",
              type: SnackBarType.success,
            );
            onSuccess?.call();
          }
        },
      ),
    );
  }

  // Sửa Option
  static void showEdit(
    BuildContext context,
    WidgetRef ref,
    Component component,
    ComponentOption option,
  ) {
    showDialog(
      context: context,
      builder: (context) => ComponentOptionDialog(
        component: component,
        option: option,
        onSave: (updatedOption) async {
          final id =
              await ref
                  .read(componentOptionProvider.notifier)
                  .updateComponentOption(updatedOption)
                  .withToast(context) ??
              0;

          if (context.mounted && id > 0) {
            ref.read(componentOptionEventProvider.notifier).notify();
            AppSnackBar.show(
              context,
              message: "Cập nhật tùy chọn thành công",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }

  // Xóa Option
  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    ComponentOption option,
  ) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDeleteDialog(
        title: "Xóa tùy chọn",
        content: "Bạn có chắc muốn xóa tùy chọn '${option.name}' không?",
        onConfirm: () async {
          final success =
              await ref
                  .read(componentOptionProvider.notifier)
                  .deleteComponentOption(option.id)
                  .withToast(context) ??
              false;

          if (context.mounted && success) {
            ref.read(componentOptionEventProvider.notifier).notify();
            AppSnackBar.show(
              context,
              message: "Đã xóa tùy chọn thành công!",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }
}
