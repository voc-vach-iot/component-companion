import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:flutter/material.dart';

enum AlertDialogSize { small, medium, big }

class AppAlertDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final AlertDialogSize size;

  const AppAlertDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.size = AlertDialogSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    double width;

    switch (size) {
      case AlertDialogSize.small:
        width = 250;
        break;
      case AlertDialogSize.big:
        width = 750;
        break;
      case AlertDialogSize.medium:
        width = 450;
    }

    return AlertDialog(
      backgroundColor: AppColors.surface, // Dùng màu surface cho Dialog
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(width: width, child: content),
      actions: [
        AppButton(
          label: "Hủy",
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
          onPressed: () => Navigator.pop(context),
        ),
        ...(actions ?? []),
      ],
      actionsPadding: const EdgeInsets.all(16),
    );
  }
}
