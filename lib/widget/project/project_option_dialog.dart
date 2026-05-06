import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ProjectOptionDialog extends HookWidget {
  final Project? project;
  final ProjectOption? projectOption; // Nếu null là Thêm, có dữ liệu là Sửa
  final Function(ProjectOption) onSave;

  const ProjectOptionDialog({
    super.key,
    this.project,
    this.projectOption,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isEditMode = projectOption != null;

    final nameCtrl = useTextEditingController(
      text: isEditMode ? projectOption!.name : "",
    );
    final descCtrl = useTextEditingController(
      text: isEditMode ? projectOption!.description : "",
    );

    return AppAlertDialog(
      title: isEditMode ? "Sửa phân loại" : "Thêm phân loại mới",
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: "Tên phân loại",
              controller: nameCtrl,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            AppTextField(label: "Mô tả", controller: descCtrl, maxLines: 2),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Lưu",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          onPressed: () {
            if (isEditMode) {
              projectOption!.name = nameCtrl.text;
              projectOption!.description = descCtrl.text;
              onSave(projectOption!);
            } else {
              final newProjectOption = ProjectOption(
                name: nameCtrl.text,
                description: descCtrl.text,
              );
              newProjectOption.project.target = project!;
              onSave(newProjectOption);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
