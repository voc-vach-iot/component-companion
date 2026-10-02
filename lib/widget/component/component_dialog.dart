import 'dart:convert';

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/constant/app_svgs.dart';
import 'package:component_companion/extension/color/color.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/component/variant_attributes_editor.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/input/svg_input.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ComponentDialog extends HookWidget {
  /// [renames] = thuộc tính / giá trị được đổi tên trong lần sửa này.
  final Function(Component component, AttributeRenames renames) onSave;
  final List<Category> categories;
  final List<ComponentType> types;
  final Component? component; // Nếu null là Thêm, nếu có giá trị là Sửa

  const ComponentDialog({
    super.key,
    required this.onSave,
    required this.categories,
    required this.types,
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
    final svgCtrl = useTextEditingController(text: component?.iconSvg ?? "");
    final svgValue = useValueListenable(svgCtrl).text.trim();

    final categoryId = useState<int>(component?.category.targetId ?? 0);
    final typeId = useState<int>(component?.type.targetId ?? 0);

    // Người dùng đã tự chọn => không tự động ghi đè nữa
    final categoryTouched = useState<bool>(categoryId.value != 0);
    final typeTouched = useState<bool>(typeId.value != 0);

    final base64ImageNotifier = useState<String>(component?.base64Image ?? "");
    final attributes = useState<List<VariantAttribute>>(
      component?.attributes ?? const [],
    );
    final renames = useState(AttributeRenames.none);
    // Số biến thể dùng mỗi giá trị, để hỏi lại khi xoá giá trị đang dùng
    final usage = useMemoized(() {
      final result = <String, Map<String, int>>{};
      for (final v in component?.variants ?? const []) {
        for (final e in v.selection.entries) {
          final counts = result.putIfAbsent(e.key, () => {});
          counts[e.value] = (counts[e.value] ?? 0) + 1;
        }
      }
      return result;
    });

    final selectedCategory = categories
        .where((c) => c.id == categoryId.value)
        .firstOrNull;
    final selectedType = types.where((t) => t.id == typeId.value).firstOrNull;

    /// Nhận diện danh mục / loại theo keyword trong tên linh kiện.
    void autoDetect({bool force = false}) {
      final name = nameCtrl.text;
      final matchedType = KeywordMatcher.bestMatch(
        name,
        types,
        (t) => t.keywords,
      );
      final matchedCategoryId =
          KeywordMatcher.bestMatch(name, categories, (c) => c.keywords)?.id ??
          matchedType?.category.targetId ??
          0;

      if (force || !typeTouched.value) {
        typeId.value = matchedType?.id ?? 0;
        typeTouched.value = false;
      }
      if (force || !categoryTouched.value) {
        categoryId.value = categories.any((c) => c.id == matchedCategoryId)
            ? matchedCategoryId
            : 0;
        categoryTouched.value = false;
      }
    }

    useEffect(() {
      void listener() => autoDetect();
      nameCtrl.addListener(listener);
      return () => nameCtrl.removeListener(listener);
    }, [nameCtrl]);

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

    Widget autoBadge(bool touched, bool hasValue) {
      if (touched || !hasValue) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.info),
            SizedBox(width: 4),
            Text(
              "Tự động nhận diện theo từ khóa",
              style: TextStyle(fontSize: 11, color: AppColors.info),
            ),
          ],
        ),
      );
    }

    return AppAlertDialog(
      title: isEditMode ? "Sửa linh kiện" : "Thêm linh kiện mới",
      size: AlertDialogSize.big,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: "Tên linh kiện",
              controller: nameCtrl,
              autofocus: true,
            ),
            const SizedBox(height: 10),
            AppTextField(label: "Mô tả", controller: descCtrl),
            const SizedBox(height: 10),

            // --- DANH MỤC + LOẠI ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSearchSelect<Category>(
                        label: "Danh mục",
                        items: categories,
                        value: selectedCategory,
                        noneLabel: "— Chưa phân loại —",
                        labelOf: (c) => c.name,
                        subtitleOf: (c) => c.description,
                        leadingOf: (c) => AppSvgIcon(
                          svg: c.iconSvg,
                          size: 18,
                          tint: true,
                          color: c.color.onPastel,
                        ),
                        onChanged: (c) {
                          categoryId.value = c?.id ?? 0;
                          categoryTouched.value = true;
                        },
                      ),
                      autoBadge(categoryTouched.value, categoryId.value != 0),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSearchSelect<ComponentType>(
                        label: "Loại linh kiện",
                        items: types,
                        value: selectedType,
                        noneLabel: "— Không xác định —",
                        labelOf: (t) => t.name,
                        subtitleOf: (t) => t.category.target?.name,
                        leadingOf: (t) => AppSvgIcon(
                          svg: t.defaultIconSvg,
                          fallbackSvg: AppSvgs.chip,
                          size: 18,
                        ),
                        onChanged: (t) {
                          typeId.value = t?.id ?? 0;
                          typeTouched.value = true;
                          // Chưa chọn danh mục thì lấy theo danh mục gợi ý của loại
                          final suggested = t?.category.targetId;
                          if (!categoryTouched.value &&
                              suggested != null &&
                              categories.any((c) => c.id == suggested)) {
                            categoryId.value = suggested;
                          }
                        },
                      ),
                      autoBadge(typeTouched.value, typeId.value != 0),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => autoDetect(force: true),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text("Nhận diện lại theo tên"),
              ),
            ),
            const SizedBox(height: 6),

            // --- BIẾN THỂ ---
            const SizedBox(height: 6),
            VariantAttributesEditor(
              initial: attributes.value,
              suggestions: selectedType?.attributeTemplate ?? const [],
              usage: usage,
              onChanged: (value, renamed) {
                attributes.value = value;
                renames.value = renamed;
              },
            ),
            const SizedBox(height: 16),

            // --- ẢNH / ICON ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Text(
                      "Hiển thị",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Tooltip(
                      message:
                          "Ưu tiên: Ảnh > Icon SVG > Icon mặc định của loại",
                      child: ComponentThumbnail(
                        base64Image: base64ImageNotifier.value,
                        iconSvg: svgValue,
                        typeIconSvg: selectedType?.defaultIconSvg ?? "",
                        categoryColor: selectedCategory?.color,
                        size: 96,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: base64ImageNotifier.value.isEmpty
                          ? "Chọn ảnh"
                          : "Đổi ảnh",
                      icon: Icons.add_a_photo_outlined,
                      variant: ButtonVariant.secondary,
                      size: ButtonSize.small,
                      onPressed: pickImage,
                    ),
                    if (base64ImageNotifier.value.isNotEmpty)
                      TextButton(
                        onPressed: () => base64ImageNotifier.value = "",
                        child: const Text("Bỏ ảnh"),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SvgInputField(
                    label: "Icon SVG riêng (tuỳ chọn)",
                    controller: svgCtrl,
                    previewColor:
                        selectedCategory?.color.onPastel ?? AppColors.textMain,
                    previewBackground: selectedCategory?.color.withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: isEditMode ? "Lưu thay đổi" : "Thêm mới",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          onPressed: () async {
            final target = component ?? Component(name: "");
            target.name = nameCtrl.text.trim();
            target.description = descCtrl.text;
            target.base64Image = base64ImageNotifier.value;
            target.iconSvg = svgValue;
            target.category.targetId = categoryId.value;
            target.type.targetId = typeId.value;
            target.attributes = attributes.value;

            await onSave(target, renames.value);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
