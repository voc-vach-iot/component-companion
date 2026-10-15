import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Hỏi nhanh 1 dòng chữ (VD giá trị thuộc tính mới). Trả về chuỗi đã trim,
/// null nếu huỷ hoặc để trống.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String hintText = "",
  String confirmLabel = "Thêm",
}) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      label: label,
      hintText: hintText,
      confirmLabel: confirmLabel,
    ),
  );
  final value = text?.trim() ?? "";
  return value.isEmpty ? null : value;
}

class _TextPromptDialog extends HookWidget {
  final String title;
  final String label;
  final String hintText;
  final String confirmLabel;

  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.hintText,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = useTextEditingController();
    final empty = useValueListenable(ctrl).text.trim().isEmpty;
    void submit() {
      if (!empty) Navigator.of(context).pop(ctrl.text);
    }

    return AppAlertDialog(
      title: title,
      size: AlertDialogSize.small,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: label, hintText: hintText),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        AppButton(
          label: confirmLabel,
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: empty,
          onPressed: submit,
        ),
      ],
    );
  }
}
