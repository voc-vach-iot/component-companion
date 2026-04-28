import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';

enum ActionType { edit, delete, export, info }

class AppActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final ActionType actionType;
  final IconData? icon; // Để null nếu muốn dùng mặc định
  final String? tooltip;

  const AppActionButton({
    super.key,
    required this.onTap,
    this.actionType = ActionType.info,
    this.icon,
    this.tooltip,
  });

  // Helper trả về icon mặc định theo type
  IconData _getDefaultIcon() {
    switch (actionType) {
      case ActionType.edit:
        return Icons.edit_outlined; // Hoặc LucideIcons.pencil
      case ActionType.delete:
        return Icons.delete_outline; // Hoặc LucideIcons.trash2
      case ActionType.export:
        return Icons.file_download_outlined;
      case ActionType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Ánh xạ màu dựa trên ActionType (Sử dụng AppColors của bạn)
    Color baseColor;
    Color hoverColor;

    switch (actionType) {
      case ActionType.edit:
        baseColor = AppColors.actionEdit;
        hoverColor = AppColors.actionEditHover;
        break;
      case ActionType.delete:
        baseColor = AppColors.actionDelete;
        hoverColor = AppColors.actionDeleteHover;
        break;
      case ActionType.export:
        baseColor = AppColors.info;
        hoverColor = AppColors.info.withValues(alpha: 0.15);
        break;
      case ActionType.info:
        baseColor = AppColors.textMuted;
        hoverColor = AppColors.primary.withValues(alpha: 0.1);
        break;
    }

    // 2. Sử dụng Tooltip để tăng trải nghiệm (rất cần cho các nút nhỏ)
    return Tooltip(
      message: tooltip ?? '',
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon ?? _getDefaultIcon(), size: 16, color: baseColor),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          enabledMouseCursor: SystemMouseCursors.click,
        ).copyWith(overlayColor: WidgetStateProperty.all(hoverColor)),
      ),
    );
  }
}
