import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Thêm / sửa 1 phương án trong nhóm lựa chọn.
class ProjectOptionDialog extends HookWidget {
  final ProjectGroup group;

  /// Phương án đang sửa (null = thêm mới).
  final ProjectOption? projectOption;

  /// Trả về true nếu lưu thành công (khi đó dialog tự đóng).
  final Future<bool> Function(ProjectOption option) onSave;

  const ProjectOptionDialog({
    super.key,
    required this.group,
    this.projectOption,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isEdit = projectOption != null;
    final nameCtrl = useTextEditingController(text: projectOption?.name ?? "");
    final descCtrl = useTextEditingController(
      text: projectOption?.description ?? "",
    );
    final name = useValueListenable(nameCtrl).text.trim();
    final saving = useState(false);

    Future<void> save() async {
      if (name.isEmpty || saving.value) return;
      saving.value = true;
      final option = ProjectOption(
        id: projectOption?.id ?? 0,
        name: name,
        description: descCtrl.text.trim(),
      )..group.targetId = group.id;
      final ok = await onSave(option);
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    return AppAlertDialog(
      title: isEdit ? "Sửa phương án" : "Thêm phương án cho \"${group.name}\"",
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: "Tên phương án",
              hintText: "VD: STM32",
              controller: nameCtrl,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            AppTextField(label: "Ghi chú", controller: descCtrl, maxLines: 2),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: isEdit ? "Lưu" : "Thêm",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: name.isEmpty || saving.value,
          onPressed: save,
        ),
      ],
    );
  }
}
