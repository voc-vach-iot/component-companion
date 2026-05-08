import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';

class AppErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorView({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              message ?? "Đã có lỗi xảy ra",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textMain,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text("Thử lại"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
