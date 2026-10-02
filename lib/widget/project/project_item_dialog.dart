import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/util/price_advisor.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/input/text_field.dart';
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

    // State cho Component, biến thể và Option đã chọn
    final selectedComp = useState<Component?>(
      isEditMode
          ? availableComponents
                .where((c) => c.id == projectItem!.component.targetId)
                .firstOrNull
          : null,
    );
    final variant = useState<VariantSelection>(
      isEditMode ? projectItem!.variant : const {},
    );
    final selectedOption = useState<ComponentOption?>(
      isEditMode
          ? selectedComp.value?.optionsList
                .where((o) => o.id == projectItem!.componentOption.targetId)
                .firstOrNull
          : null,
    );

    final quantityCtrl = useTextEditingController(
      text: isEditMode ? projectItem!.quantity.toString() : "1",
    );
    final quantity = int.tryParse(useValueListenable(quantityCtrl).text) ?? 0;

    final component = selectedComp.value;
    final attributes = component?.attributes ?? const <VariantAttribute>[];
    final options = component == null
        ? const <ComponentOption>[]
        : PriceAdvisor.availableOptions(component, variant.value);
    final cheapestId = options.firstOrNull?.id;
    final variantComplete = attributes.every(
      (a) => variant.value[a.name] != null,
    );

    /// Giữ tuỳ chọn đang chọn nếu còn hợp lệ, không thì chọn rẻ nhất.
    void ensureOption(Component comp, VariantSelection v) {
      final available = PriceAdvisor.availableOptions(comp, v);
      if (!available.any((o) => o.id == selectedOption.value?.id)) {
        selectedOption.value = available.firstOrNull;
      }
    }

    final stock = component == null || !variantComplete
        ? null
        : component.stockItems.isEmpty
        ? null
        : component.stockOf(variant.value);

    return AppAlertDialog(
      title: isEditMode ? "Sửa linh kiện" : "Thêm linh kiện",
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSearchSelect<Component>(
                label: "Linh kiện",
                hintText: "Chọn linh kiện...",
                items: availableComponents,
                value: selectedComp.value,
                labelOf: (c) => c.name,
                subtitleOf: (c) => [
                  c.category.target?.name,
                  c.type.target?.name,
                ].whereType<String>().join(" · "),
                leadingOf: (c) => ComponentThumbnail.of(c, size: 32),
                onChanged: (comp) {
                  if (comp == null || comp.id == selectedComp.value?.id) return;
                  selectedComp.value = comp;
                  // Biến thể: giữ giá trị còn hợp lệ, thuộc tính 1 giá trị thì chọn luôn
                  variant.value = {
                    for (final a in comp.attributes)
                      if (a.values.length == 1)
                        a.name: a.values.first
                      else if (a.values.contains(variant.value[a.name]))
                        a.name: variant.value[a.name]!,
                  };
                  selectedOption.value = null;
                  ensureOption(comp, variant.value);
                },
              ),

              // --- BIẾN THỂ ---
              for (final a in attributes) ...[
                const SizedBox(height: 12),
                Text(
                  a.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final value in a.values)
                      ChoiceChip(
                        label: Text(value),
                        selected: variant.value[a.name] == value,
                        onSelected: (_) {
                          variant.value = {...variant.value, a.name: value};
                          ensureOption(component!, variant.value);
                        },
                      ),
                  ],
                ),
              ],

              if (component != null) ...[
                const SizedBox(height: 16),
                AppSearchSelect<ComponentOption>(
                  // Đổi linh kiện => tạo lại ô chọn quy cách
                  key: ValueKey(component.id),
                  label: "Mua ở đâu (tùy chọn)",
                  hintText: options.isEmpty
                      ? "Chưa có tùy chọn mua hàng phù hợp"
                      : "Chọn tùy chọn...",
                  items: options,
                  value: selectedOption.value,
                  labelOf: (opt) =>
                      [if (opt.shop.isNotEmpty) opt.shop, opt.name].join(" · "),
                  subtitleOf: (opt) =>
                      "${opt.pricePerUnit.toVND()}/cái · gói ${opt.unitsPerPack} cái ${opt.pricePerPack.toVND()}"
                      "${opt.id == cheapestId && options.length > 1 ? "  ★ rẻ nhất" : ""}",
                  onChanged: (val) => selectedOption.value = val,
                ),
              ],

              const SizedBox(height: 16),
              AppTextField(
                label: "Số lượng cần (cái)",
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              if (selectedOption.value != null && quantity > 0)
                Text(
                  "Thành tiền: ${(selectedOption.value!.pricePerUnit * quantity).toVND()}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (stock != null)
                Text(
                  stock >= quantity
                      ? "Kho đang có $stock cái — đủ dùng"
                      : "Kho đang có $stock cái — thiếu ${quantity - stock} cái",
                  style: TextStyle(
                    fontSize: 12,
                    color: stock >= quantity
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: "Lưu",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled:
              component == null ||
              selectedOption.value == null ||
              !variantComplete ||
              quantity <= 0,
          onPressed: () {
            final item = projectItem ?? ProjectItem();
            item.quantity = quantity;
            item.variant = variant.value;
            item.component.targetId = component!.id;
            item.componentOption.targetId = selectedOption.value!.id;
            if (!isEditMode) {
              item.project.targetId = project?.id ?? 0;
              item.projectOption.targetId = projectOption?.id ?? 0;
            }
            onSave(item);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
