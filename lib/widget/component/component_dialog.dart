import 'dart:convert';

import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/input/dropdown.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ComponentDialog extends HookWidget {
  final Function(Component) onSave;
  final List<Category> categories;
  final Component? component; // Nếu null là Thêm, nếu có giá trị là Sửa

  const ComponentDialog({
    super.key,
    required this.onSave,
    required this.categories,
    this.component,
  });

  @override
  Widget build(BuildContext context) {
    // Xác định mode dựa trên việc có truyền component vào hay không
    final isEditMode = component != null;

    // Khởi tạo controller với giá trị ban đầu nếu là mode Sửa
    final nameCtrl = useTextEditingController(text: component?.name ?? "");
    final descCtrl = useTextEditingController(
      text: component?.description ?? "",
    );

    final selectedCategory = categories.firstWhere(
      (c) => c.id == component?.category.target?.id,
      orElse: () => categories.first,
    );

    final selectedCategoryNotifier = useState<Category?>(selectedCategory);

    final base64ImageNotifier = useState<String>(component?.base64Image ?? "");

    Future<void> pickImage() async {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        base64ImageNotifier.value = base64Encode(bytes);
      }
    }

    return AppAlertDialog(
      title: isEditMode ? "Sửa linh kiện" : "Thêm linh kiện mới",
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- UPLOAD ẢNH ---
              InkWell(
                borderRadius: BorderRadius.circular(12),
                mouseCursor: SystemMouseCursors.click,
                onTap: pickImage,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: base64ImageNotifier.value.isEmpty
                      ? const Icon(Icons.add_a_photo)
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

              AppTextField(label: "Tên linh kiện", controller: nameCtrl, autofocus: true,),
              const SizedBox(height: 10),
              AppTextField(label: "Mô tả", controller: descCtrl),
              const SizedBox(height: 10),

              AppDropdown<Category>(
                label: "Danh mục",
                initialValue: selectedCategoryNotifier.value,
                items: categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icon, size: 16),
                            const SizedBox(width: 8),
                            Text(c.name, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => selectedCategoryNotifier.value = val,
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: isEditMode ? "Lưu thay đổi" : "Thêm mới",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          onPressed: () async {
            if (isEditMode) {
              component!.name = nameCtrl.text;
              component!.description = descCtrl.text;
              component!.base64Image = base64ImageNotifier.value;

              if (selectedCategoryNotifier.value != null) {
                component!.category.target = selectedCategoryNotifier.value;
              }
              await onSave(component!);
            } else {
              final newComponent = Component(
                name: nameCtrl.text,
                description: descCtrl.text,
                base64Image: base64ImageNotifier.value,
              );
              if (selectedCategoryNotifier.value != null) {
                newComponent.category.target = selectedCategoryNotifier.value;
              }
              await onSave(newComponent);
            }
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
