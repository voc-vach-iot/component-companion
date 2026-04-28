import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:flutter/material.dart';

class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;

  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: const TextStyle(color: AppColors.actionDelete)),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Text(content),
      actions: [
        AppButton(
          label: "Huỷ",
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label: "Xoá",
          variant: ButtonVariant.danger,
          size: ButtonSize.small,
          onPressed: () {
            onConfirm();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
