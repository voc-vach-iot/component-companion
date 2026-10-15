import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Thêm / đổi tên nhóm lựa chọn. Khi thêm có thể gõ luôn các phương án.
class ProjectGroupDialog extends HookWidget {
  /// Nhóm đang sửa (null = thêm mới).
  final ProjectGroup? group;

  /// Trả về true nếu lưu thành công (khi đó dialog tự đóng).
  final Future<bool> Function(String name, List<String> optionNames) onSave;

  const ProjectGroupDialog({super.key, this.group, required this.onSave});

  /// "ESP32, STM32" hoặc mỗi dòng 1 phương án.
  static List<String> splitOptions(String text) => text
      .split(RegExp(r'[,;\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final isEdit = group != null;
    final nameCtrl = useTextEditingController(text: group?.name ?? "");
    final optionsCtrl = useTextEditingController();
    final name = useValueListenable(nameCtrl).text.trim();
    final options = splitOptions(useValueListenable(optionsCtrl).text);
    final saving = useState(false);

    Future<void> save() async {
      if (name.isEmpty || saving.value) return;
      saving.value = true;
      final ok = await onSave(name, options);
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    return AppAlertDialog(
      title: isEdit ? "Đổi tên nhóm lựa chọn" : "Thêm nhóm lựa chọn",
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isEdit) ...[
              const Text(
                "Nhóm gồm các phương án thay thế nhau, mỗi lúc dùng 1 phương án. "
                "VD nhóm \"Vi điều khiển\": ESP32 / STM32; nhóm \"Pin\": "
                "1000mAh / 2000mAh. Các nhóm kết hợp tự do, không cần tạo đủ "
                "mọi tổ hợp.",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
            ],
            AppTextField(
              label: "Tên nhóm",
              hintText: "VD: Vi điều khiển",
              controller: nameCtrl,
              autofocus: true,
            ),
            if (!isEdit) ...[
              const SizedBox(height: 12),
              AppTextField(
                label: "Các phương án (cách nhau bởi dấu phẩy)",
                hintText: "VD: ESP32, STM32",
                controller: optionsCtrl,
              ),
              const SizedBox(height: 6),
              Text(
                options.isEmpty
                    ? "Để trống => tạo 1 phương án \"Phương án 1\", thêm sau cũng được."
                    : "Sẽ tạo ${options.length} phương án, dùng \"${options.first}\" trước.",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          label: isEdit ? "Lưu" : "Thêm nhóm",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: name.isEmpty || saving.value,
          onPressed: save,
        ),
      ],
    );
  }
}
