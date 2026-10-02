import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/color/color.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/input/keyword_input.dart';
import 'package:component_companion/widget/input/svg_input.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ComponentTypeDialog extends HookWidget {
  final ComponentType? type; // Nếu null là Thêm, có giá trị là Sửa
  final List<Category> categories;
  final Function(ComponentType) onSave;

  /// Trả về thông báo lỗi nếu keyword đã thuộc loại khác.
  final String? Function(String keyword)? keywordValidator;

  const ComponentTypeDialog({
    super.key,
    this.type,
    required this.categories,
    required this.onSave,
    this.keywordValidator,
  });

  @override
  Widget build(BuildContext context) {
    final isEdit = type != null;

    final nameController = useTextEditingController(text: type?.name ?? "");
    final svgController = useTextEditingController(
      text: type?.defaultIconSvg ?? "",
    );
    final keywords = useState<List<String>>(type?.keywords ?? []);
    final selectedCategoryId = useState<int>(type?.category.targetId ?? 0);

    final selectedCategory = categories
        .where((c) => c.id == selectedCategoryId.value)
        .firstOrNull;
    final accentColor = selectedCategory?.color ?? AppColors.surfaceVariant;

    return AppAlertDialog(
      title: isEdit ? "Sửa loại linh kiện" : "Thêm loại linh kiện",
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: "Tên loại (VD: Tụ hóa, Trở sứ...)",
                controller: nameController,
                autofocus: true,
              ),
              const SizedBox(height: 16),

              AppSearchSelect<Category>(
                label: "Danh mục gợi ý",
                items: categories,
                value: selectedCategory,
                noneLabel: "— Không gắn danh mục —",
                labelOf: (c) => c.name,
                subtitleOf: (c) => c.description,
                leadingOf: (c) => AppSvgIcon(
                  svg: c.iconSvg,
                  size: 18,
                  tint: true,
                  color: c.color.onPastel,
                ),
                onChanged: (c) => selectedCategoryId.value = c?.id ?? 0,
              ),
              const SizedBox(height: 4),
              const Text(
                "Khi linh kiện được nhận diện thuộc loại này mà không khớp danh mục nào, danh mục này sẽ được dùng.",
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              SvgInputField(
                label: "Icon mặc định (SVG)",
                controller: svgController,
                previewBackground: accentColor.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 4),
              const Text(
                "Linh kiện thuộc loại này sẽ dùng icon này làm ảnh nếu chưa gắn ảnh / icon riêng.",
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              KeywordInput(
                initialKeywords: keywords.value,
                onChanged: (value) => keywords.value = value,
                validator: keywordValidator,
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
            final target = type ?? ComponentType(name: "");
            target.name = nameController.text.trim();
            target.defaultIconSvg = svgController.text.trim();
            target.keywords = keywords.value;
            target.category.targetId = selectedCategoryId.value;
            onSave(target);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
