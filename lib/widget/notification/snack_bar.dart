import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';

enum SnackBarType { success, error, warning, info }

class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Bảo vệ hàm nếu context đã bị hủy trước khi gọi
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    Color backgroundColor;
    IconData icon;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case SnackBarType.error:
        backgroundColor = AppColors.error;
        icon = Icons.error_outline;
        break;
      case SnackBarType.warning:
        backgroundColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case SnackBarType.info:
        backgroundColor = AppColors.info;
        icon = Icons.info_outline;
        break;
    }

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                style: IconButton.styleFrom(
                  enabledMouseCursor: SystemMouseCursors.click,
                ),
                onPressed: () =>
                    messenger.hideCurrentSnackBar(), // Dùng messenger đã lưu
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
