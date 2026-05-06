import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/input/autocomplete.dart';
import 'package:component_companion/widget/input/dropdown.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ProjectItemDialog extends HookWidget {
  final Project? project;
  final ProjectOption? projectOption; // Null = Thêm, Có giá trị = Sửa
  final ProjectItem? projectItem;
  final Function(ProjectItem) onSave;
  final List<Component> availableComponents;

  const ProjectItemDialog({
    super.key,
    this.project,
    this.projectOption,
    this.projectItem,
    required this.onSave,
    required this.availableComponents,
  });

  @override
  Widget build(BuildContext context) {
    final isEditMode = projectItem != null;

    // State cho Component và Option đã chọn
    final selectedComp = useState<Component?>(
      isEditMode
          ? availableComponents.firstWhere(
              (c) => c.id == projectItem!.component.targetId,
            )
          : null,
    );

    final selectedOption = useState<ComponentOption?>(
      isEditMode
          ? availableComponents
                .expand((c) => c.options)
                .firstWhere(
                  (o) => o.id == projectItem!.componentOption.targetId,
                )
          : null,
    );

    final quantityCtrl = useTextEditingController(
      text: isEditMode ? projectItem!.quantity.toString() : "1",
    );

    return AppAlertDialog(
      title: isEditMode ? "Sửa linh kiện" : "Thêm linh kiện",
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAutocomplete<Component>(
              label: "Tìm linh kiện",
              options: availableComponents,
              // Hiển thị giá trị ban đầu nếu đang ở Edit Mode
              initialValue: selectedComp.value,
              displayStringForOption: (c) => c.name,
              onSelected: (comp) {
                selectedComp.value = comp;
                selectedOption.value = null; // Reset option khi đổi linh kiện
              },
            ),
            const SizedBox(height: 16),

            if (selectedComp.value != null)
              AppDropdown<ComponentOption>(
                label: "Quy cách đóng gói",
                initialValue: selectedOption.value,
                items: selectedComp.value!.optionsList
                    .map(
                      (opt) => DropdownMenuItem(
                        value: opt,
                        child: Text(
                          "${opt.name} (${opt.unitsPerPack} cái) - ${opt.pricePerPack}đ",
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => selectedOption.value = val,
              ),

            const SizedBox(height: 16),
            AppTextField(
              label: "Số lượng gói",
              controller: quantityCtrl,
              keyboardType: TextInputType.number,
            ),
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
              final updatedItem = projectItem!;
              updatedItem.quantity = int.tryParse(quantityCtrl.text) ?? 1;
              updatedItem.component.targetId = selectedComp.value!.id;
              updatedItem.componentOption.targetId = selectedOption.value!.id;

              onSave(updatedItem);
            } else {
              final item = ProjectItem(quantity: 1);
              item.quantity = int.tryParse(quantityCtrl.text) ?? 1;
              item.project.target = project;
              item.projectOption.target = projectOption;
              item.component.targetId = selectedComp.value!.id;
              item.componentOption.targetId = selectedOption.value!.id;

              onSave(item);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
