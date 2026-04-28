import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';

enum ButtonVariant { primary, secondary, danger, success }

enum ButtonSize { small, medium, big }

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isDisabled;
  final ButtonVariant variant;
  final ButtonSize size;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isDisabled = false,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    // Định nghĩa màu sắc dựa trên variant
    Color bgColor;
    Color fgColor;

    double horizonalPadding;
    double verticalPadding;

    switch (variant) {
      case ButtonVariant.secondary:
        bgColor = AppColors.surfaceVariant;
        fgColor = AppColors.textMain;
        break;
      case ButtonVariant.primary:
        bgColor = AppColors.primary;
        fgColor = AppColors.textMain;
        break;
      case ButtonVariant.success:
        bgColor = AppColors.surfaceVariant;
        fgColor = AppColors.success;
      case ButtonVariant.danger:
        bgColor = AppColors.surfaceVariant;
        fgColor = AppColors.error;
    }

    switch (size) {
      case ButtonSize.small:
        horizonalPadding = 20;
        verticalPadding = 20;
        break;
      case ButtonSize.medium:
        horizonalPadding = 24;
        verticalPadding = 24;
        break;

      case ButtonSize.big:
        horizonalPadding = 30;
        verticalPadding = 30;
        break;
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: isDisabled ? bgColor.withValues(alpha: 0.3) : bgColor,
      foregroundColor: isDisabled ? fgColor.withValues(alpha: 0.5) : fgColor,
      elevation: 0, // Flat design hiện đại
      padding: EdgeInsets.symmetric(
        horizontal: horizonalPadding,
        vertical: verticalPadding,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      enabledMouseCursor: SystemMouseCursors.click,
      disabledMouseCursor: SystemMouseCursors.forbidden,
    );

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: isDisabled ? null : onPressed,
        style: buttonStyle,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    }

    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: buttonStyle,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
