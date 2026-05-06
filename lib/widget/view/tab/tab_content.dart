import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppTabContent extends HookConsumerWidget {
  final String title;
  final String? description;
  final Widget? headerAction;
  final Widget child;

  const AppTabContent({
    super.key,
    required this.title,
    this.headerAction,
    required this.child,
    this.description,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Sửa cú pháp check null ở đây
              ?headerAction,
            ],
          ),
          const SizedBox(height: 16),

          // Nội dung chính
          // Expanded ở đây để GenericList (ListView) có thể cuộn được trong Column
          Expanded(child: child),
        ],
      ),
    );
  }
}
