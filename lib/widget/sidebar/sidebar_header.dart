import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/constant/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SidebarHeader extends StatelessWidget {
  final bool isCollapsed;

  const SidebarHeader({super.key, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Bỏ height: 80 đi, dùng constraints để nó linh hoạt
      constraints: const BoxConstraints(maxHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: AppColors.sidebarHeader,
      child: Center(
        // Dùng Center để nội dung luôn giữa dù kích thước thay đổi
        child: isCollapsed
            ? const Icon(LucideIcons.cpu, size: 32)
            : Column(
                mainAxisSize:
                    MainAxisSize.min, // QUAN TRỌNG: Co lại theo nội dung
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppStrings.appName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1, // Tránh tràn chữ
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }
}
