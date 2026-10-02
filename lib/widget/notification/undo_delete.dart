import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';

/// Xoá có thể hoàn tác: chụp lại dữ liệu trước khi xoá, sau khi xoá hiện
/// snackbar có nút "Hoàn tác" trong vài giây.
class UndoDelete {
  UndoDelete._();

  static const _undoWindow = Duration(seconds: 10);

  /// [context] phải là context của trang (không phải của dialog xác nhận vì
  /// dialog đã đóng khi xoá xong).
  static Future<bool> run(
    BuildContext context, {
    required DataSnapshot Function(DataTransferService transfer) snapshot,
    required Future<bool> Function() delete,
    required String message,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final transfer = DataTransferService();
    final data = snapshot(transfer);

    final success = await delete().withToast(context) ?? false;
    if (!success) return false;

    AppSnackBar.showWith(
      messenger,
      message: message,
      type: SnackBarType.success,
      duration: _undoWindow,
      actionLabel: "Hoàn tác",
      onAction: () {
        try {
          transfer.restore(data);
          AppSnackBar.showWith(
            messenger,
            message: "Đã hoàn tác",
            type: SnackBarType.info,
          );
        } catch (e) {
          AppSnackBar.showWith(
            messenger,
            message: "Không thể hoàn tác: $e",
            type: SnackBarType.error,
          );
        }
      },
    );
    return true;
  }
}
