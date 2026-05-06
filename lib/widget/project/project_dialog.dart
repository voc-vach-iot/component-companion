import 'dart:convert';
import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/input/dropdown.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ProjectDialog extends HookWidget {
  final Function(Project) onSave;
  final Project? project; // Null là Thêm, có giá trị là Sửa

  const ProjectDialog({super.key, required this.onSave, this.project});

  @override
  Widget build(BuildContext context) {
    final isEditMode = project != null;

    // Controllers
    final nameCtrl = useTextEditingController(text: project?.name ?? "");
    final descCtrl = useTextEditingController(text: project?.description ?? "");

    // State management
    final selectedStatusNotifier = useState<ProjectStatus>(
      project?.projectStatus ?? ProjectStatus.planning,
    );
    final base64ImageNotifier = useState<String>(project?.base64Image ?? "");

    Future<void> pickImage() async {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        base64ImageNotifier.value = base64Encode(result.files.single.bytes!);
      }
    }

    return AppAlertDialog(
      title: isEditMode ? "Sửa dự án" : "Thêm dự án mới",
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- UPLOAD ẢNH ---
              InkWell(
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(12),
                onTap: pickImage,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: base64ImageNotifier.value.isEmpty
                      ? const Icon(Icons.add_a_photo, color: Colors.grey)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(base64ImageNotifier.value),
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              AppTextField(label: "Tên dự án", controller: nameCtrl),
              const SizedBox(height: 10),
              AppTextField(label: "Mô tả", controller: descCtrl),
              const SizedBox(height: 10),

              // --- TRẠNG THÁI ---
              AppDropdown<ProjectStatus>(
                label: "Trạng thái",
                initialValue: selectedStatusNotifier.value,
                items: ProjectStatus.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Icon(s.icon, size: 16, color: s.color),
                            const SizedBox(width: 8),
                            Text(s.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => selectedStatusNotifier.value = val!,
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: isEditMode ? "Lưu thay đổi" : "Tạo dự án",
          variant: ButtonVariant.primary,
          onPressed: () async {
            if (isEditMode) {
              project!.name = nameCtrl.text;
              project!.description = descCtrl.text;
              project!.base64Image = base64ImageNotifier.value;
              project!.status = selectedStatusNotifier.value.name;
              project!.updatedAt = DateTime.now().millisecondsSinceEpoch;
              await onSave(project!);
            } else {
              final newProject = Project(
                name: nameCtrl.text,
                description: descCtrl.text,
              );
              newProject.base64Image = base64ImageNotifier.value;
              newProject.status = selectedStatusNotifier.value.name;
              await onSave(newProject);
            }
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
