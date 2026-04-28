import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/input/search_bar.dart';
import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAddPressed; // Để null nếu không cần nút thêm
  final ValueChanged<String>? onSearch; // Để null nếu không cần search
  final Widget?
  trailing; // Tùy biến nút bấm (ví dụ: nút "Chọn", "Xuất file",...)

  const AppHeader({
    super.key,
    required this.title,
    this.onAddPressed,
    this.onSearch,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Row(
          children: [
            if (onSearch != null)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.searchBarBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderStrong.withValues(alpha: 0.5),
                    ),
                  ),
                  child: AppSearchBar(onSearch: onSearch!),
                ),
              ),
            if (onSearch != null && (onAddPressed != null || trailing != null))
              const SizedBox(width: 16),

            // Ưu tiên nút thêm, nếu không có thì hiện trailing tùy chỉnh
            if (onAddPressed != null)
              AppButton(
                onPressed: onAddPressed!,
                label: "Thêm mới",
                icon: Icons.add,
                variant: ButtonVariant.primary,
              ),
            ?trailing,
          ],
        ),
      ],
    );
  }
}
