import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/notifier/component_option_notifier.dart';
import 'package:component_companion/widget/component/component_option_dialog.dart';
import 'package:component_companion/widget/component/price_history_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ComponentOptionAction {
  // Thêm Option
  static void showAdd(
    BuildContext context,
    WidgetRef ref,
    Component component, {
    ValueChanged<int>? onSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => ComponentOptionDialog(
        component: component,
        knownShops: ref.read(componentOptionRepositoryProvider).distinctShops(),
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
            AppSnackBar.show(
              context,
              message: "Thêm tùy chọn thành công",
              type: SnackBarType.success,
            );
            onSuccess?.call(id);
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
        knownShops: ref.read(componentOptionRepositoryProvider).distinctShops(),
        option: option,
        onSave: (updatedOption) async {
          final id =
              await ref
                  .read(componentOptionProvider.notifier)
                  .updateComponentOption(updatedOption)
                  .withToast(context) ??
              0;

          if (context.mounted && id > 0) {
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

  // Xác nhận giá vẫn đúng (đã kiểm tra lại trên shop)
  static Future<void> confirmPrice(
    BuildContext context,
    WidgetRef ref,
    ComponentOption option,
  ) async {
    final id =
        await ref
            .read(componentOptionProvider.notifier)
            .confirmPrice(option.id)
            .withToast(context) ??
        0;
    if (context.mounted && id > 0) {
      AppSnackBar.show(
        context,
        message: "Đã ghi nhận giá hôm nay của '${option.name}'",
        type: SnackBarType.success,
      );
    }
  }

  // Lịch sử giá
  static void showHistory(BuildContext context, ComponentOption option) {
    showDialog(
      context: context,
      builder: (context) => PriceHistoryDialog(option: option),
    );
  }

  // Nhân bản Option
  static Future<void> clone(
    BuildContext context,
    WidgetRef ref,
    ComponentOption option,
  ) async {
    final id =
        await ref
            .read(componentOptionProvider.notifier)
            .cloneComponentOption(option.id)
            .withToast(context) ??
        0;
    if (context.mounted && id > 0) {
      AppSnackBar.show(
        context,
        message: "Đã nhân bản tùy chọn '${option.name}'",
        type: SnackBarType.success,
      );
    }
  }

  // Xóa Option
  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    ComponentOption option,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa tùy chọn",
        content: "Bạn có chắc muốn xóa tùy chọn '${option.name}' không?",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(optionIds: [option.id]),
          delete: () => ref
              .read(componentOptionProvider.notifier)
              .deleteComponentOption(option.id),
          message: "Đã xóa tùy chọn '${option.name}'",
        ),
      ),
    );
  }
}
