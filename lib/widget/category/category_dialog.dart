import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/enum/category_color.dart';
import 'package:component_companion/extension/color/color.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/keyword_input.dart';
import 'package:component_companion/widget/input/svg_input.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class CategoryDialog extends HookWidget {
  final Category? category; // Nếu null là Thêm, có giá trị là Sửa
  final Function(Category) onSave;

  /// Trả về thông báo lỗi nếu keyword đã thuộc danh mục khác.
  final String? Function(String keyword)? keywordValidator;

  const CategoryDialog({
    super.key,
    this.category,
    required this.onSave,
    this.keywordValidator,
  });

  @override
  Widget build(BuildContext context) {
    final isEdit = category != null;

    // Helper: Chuyển từ Color (ARGB) sang Hex 6 ký tự để hiển thị
    String colorToHex(Color color) {
      return color
          .toARGB32()
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2)
          .toUpperCase();
    }

    // Helper: Chuyển từ chuỗi Hex (6 ký tự) sang Color (ARGB) để lưu DB
    Color hexToColor(String hex) {
      // Đảm bảo luôn có FF ở đầu
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    }

    final nameController = useTextEditingController(text: category?.name ?? "");
    // 1. Khởi tạo Controller: Nếu có category thì convert sang Hex 6 ký tự
    final colorController = useTextEditingController(
      text: category != null
          ? colorToHex(Color(category!.colorValue))
          : colorToHex(CategoryColor.values.first.color),
    );
    final descriptionController = useTextEditingController(
      text: category?.description ?? "",
    );
    final svgController = useTextEditingController(
      text: category?.iconSvg ?? "",
    );
    final keywords = useState<List<String>>(category?.keywords ?? []);
    final selectedColor = useState<Color>(
      category?.color ?? CategoryColor.values.first.color,
    );

    // 2. Hàm updateColor (Dùng cho ColorPicker và List màu)
    void updateColor(Color color) {
      selectedColor.value = color;
      colorController.text = colorToHex(color);
    }

    // 3. Logic useEffect (Để người dùng tự nhập Hex vào Textfield)
    useEffect(() {
      void listener() {
        final hex = colorController.text.replaceAll('#', '');
        if (hex.length == 6) {
          try {
            selectedColor.value = hexToColor(hex);
          } catch (_) {}
        }
      }

      colorController.addListener(listener);
      return () => colorController.removeListener(listener);
    }, [colorController]);

    return AppAlertDialog(
      title: isEdit ? "Sửa danh mục" : "Thêm danh mục mới",
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: "Tên danh mục",
                controller: nameController,
                autofocus: true,
              ),
              const SizedBox(height: 20),

              AppTextField(label: "Mô tả", controller: descriptionController),
              const SizedBox(height: 20),

              SvgInputField(
                label: "Icon (SVG)",
                controller: svgController,
                tint: true,
                previewColor: selectedColor.value.onPastel,
                previewBackground: selectedColor.value.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 4),
              const Text(
                "Dán SVG từ Lucide / Font Awesome... Để trống sẽ dùng icon mặc định.",
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),

              KeywordInput(
                initialKeywords: keywords.value,
                onChanged: (value) => keywords.value = value,
                validator: keywordValidator,
              ),
              const SizedBox(height: 20),

              const Text(
                "Chọn màu sắc:",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: colorController,
                      decoration: const InputDecoration(
                        labelText: "Mã màu Hex",
                        border: OutlineInputBorder(),
                        prefixText: "#",
                      ),
                      maxLength: 8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Chọn màu tùy chỉnh'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: selectedColor.value,
                            onColorChanged: (c) {
                              selectedColor.value = c;
                              colorController.text = c
                                  .toARGB32()
                                  .toRadixString(16)
                                  .substring(2)
                                  .toUpperCase();
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Xong'),
                          ),
                        ],
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: selectedColor.value,
                      radius: 20,
                      child: const Icon(
                        Icons.colorize,
                        size: 16,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: CategoryColor.values
                    .map(
                      (item) => Tooltip(
                        message: item.label,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            mouseCursor: SystemMouseCursors.click,
                            customBorder: const CircleBorder(),
                            onTap: () => updateColor(item.color),
                            child: CircleAvatar(
                              backgroundColor: item.color,
                              radius: 16,
                              child: selectedColor.value == item.color
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.black26,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: isEdit ? "Lưu thay đổi" : "Thêm mới",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          onPressed: () {
            final finalColor = hexToColor(colorController.text);

            if (isEdit) {
              category!.name = nameController.text;
              category!.colorValue = finalColor
                  .toARGB32(); // Lưu giá trị ARGB nguyên bản
              category!.description = descriptionController.text.trim();
              category!.iconSvg = svgController.text.trim();
              category!.keywords = keywords.value;
              onSave(category!);
            } else {
              final newCategory = Category(
                name: nameController.text,
                colorValue: finalColor.toARGB32(),
                description: descriptionController.text.trim(),
                iconSvg: svgController.text.trim(),
                keywords: keywords.value,
              );
              onSave(newCategory);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
