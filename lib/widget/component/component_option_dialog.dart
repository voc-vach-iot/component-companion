import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ComponentOptionDialog extends HookWidget {
  final Component component;
  final ComponentOption? option; // Null = Thêm, Có giá trị = Sửa
  final Function(ComponentOption) onSave;

  const ComponentOptionDialog({
    super.key,
    required this.component,
    this.option,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isEditMode = option != null;

    final nameCtrl = useTextEditingController(text: option?.name ?? "");
    final unitsCtrl = useTextEditingController(
      text: option?.unitsPerPack.toString() ?? "1",
    );
    final priceCtrl = useTextEditingController(
      text: option?.pricePerPack.toString() ?? "0",
    );
    final linkCtrl = useTextEditingController(text: option?.link ?? "");

    return AppAlertDialog(
      title: isEditMode ? "Sửa tùy chọn" : "Thêm tùy chọn mới",
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: "Tên tùy chọn (VD: 100 cái)",
                controller: nameCtrl,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: "Số lượng/gói",
                      controller: unitsCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: "Giá tiền",
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: "Link mua hàng",
                controller: linkCtrl,
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: isEditMode ? "Lưu thay đổi" : "Thêm mới",
          variant: ButtonVariant.primary,
          onPressed: () async {
            final newOption =
                option ??
                ComponentOption(
                  name: nameCtrl.text,
                  pricePerPack: int.tryParse(priceCtrl.text) ?? 0,
                );

            newOption.name = nameCtrl.text;
            newOption.unitsPerPack = int.tryParse(unitsCtrl.text) ?? 1;
            newOption.pricePerPack = int.tryParse(priceCtrl.text) ?? 0;
            newOption.link = linkCtrl.text;

            // Gán link component
            newOption.component.target = component;

            await onSave(newOption);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}
