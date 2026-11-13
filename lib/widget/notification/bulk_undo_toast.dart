import 'package:component_companion/service/bulk_edit_service.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';

/// Báo kết quả thao tác hàng loạt kèm nút "Hoàn tác" trong vài giây.
/// [undo] null = thao tác không hoàn tác được (chỉ báo kết quả).
class BulkUndoToast {
  BulkUndoToast._();

  static const _undoWindow = Duration(seconds: 10);

  static void show(
    BuildContext context, {
    required String message,
    BulkUndo? undo,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    AppSnackBar.showWith(
      messenger,
      message: message,
      type: SnackBarType.success,
      duration: undo == null ? const Duration(seconds: 3) : _undoWindow,
      actionLabel: undo == null ? null : "Hoàn tác",
      onAction: undo == null
          ? null
          : () {
              try {
                undo.run();
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
  }
}
