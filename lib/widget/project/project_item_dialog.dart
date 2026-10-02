import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/util/purchase_planner.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ProjectItemDialog extends HookWidget {
  final Project? project;
  final ProjectOption? projectOption;
  final ProjectItem? projectItem; // Null = Thêm, Có giá trị = Sửa
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

    final selectedComp = useState<Component?>(
      isEditMode
          ? availableComponents
                .where((c) => c.id == projectItem!.component.targetId)
                .firstOrNull
          : null,
    );
    final component = selectedComp.value;
    final variants = useMemoized(
      () => component?.sortedVariants ?? const <ComponentVariant>[],
      [component?.id],
    );

    final selectedVariant = useState<ComponentVariant?>(
      isEditMode
          ? variants
                .where((v) => v.id == projectItem!.variant.targetId)
                .firstOrNull
          : null,
    );
    final variant = selectedVariant.value;

    final quantityCtrl = useTextEditingController(
      text: isEditMode ? projectItem!.quantity.toString() : "1",
    );
    final quantity = int.tryParse(useValueListenable(quantityCtrl).text) ?? 0;
    final need = quantity <= 0 ? 1 : quantity;

    // Tuỳ chọn mua của biến thể, rẻ nhất theo TỔNG TIỀN cho số lượng cần
    final offers = variant == null
        ? const <ComponentOption>[]
        : (variant.options.toList()..sort((a, b) {
            final byCost = PurchasePlanner.singleCost(
              a,
              need,
            ).compareTo(PurchasePlanner.singleCost(b, need));
            return byCost != 0
                ? byCost
                : a.pricePerUnit.compareTo(b.pricePerUnit);
          }));
    final best = PurchasePlanner.bestSingle(offers, need);

    final selectedOption = useState<ComponentOption?>(
      isEditMode
          ? offers
                .where((o) => o.id == projectItem!.componentOption.targetId)
                .firstOrNull
          : null,
    );
    // Người dùng tự chọn tuỳ chọn => không tự đổi sang rẻ nhất nữa
    final optionTouched = useState(isEditMode);

    final offerKey = offers.map((o) => o.id).join(",");
    useEffect(() {
      final current = selectedOption.value;
      final valid = offers.any((o) => o.id == current?.id);
      if (!valid || !optionTouched.value) {
        if (best?.id != current?.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) selectedOption.value = best;
          });
        }
      }
      return null;
    }, [offerKey, need]);

    void pickComponent(Component? comp) {
      if (comp == null || comp.id == selectedComp.value?.id) return;
      selectedComp.value = comp;
      final list = comp.sortedVariants;
      // Linh kiện chỉ có 1 biến thể (hoặc không có thuộc tính) => chọn luôn
      selectedVariant.value = list.length == 1 ? list.first : null;
      selectedOption.value = null;
      optionTouched.value = false;
    }

    final stock = variant?.stock;
    final option = selectedOption.value;
    final optionCost = option == null
        ? null
        : PurchasePlanner.singleCost(option, need);

    String variantSubtitle(ComponentVariant v) {
      final cheapest = PurchasePlanner.bestSingle(v.options, need);
      return [
        v.stock == null ? "Chưa nhập kho" : "Kho: ${v.stock}",
        if (cheapest != null) "từ ${cheapest.pricePerUnit.toVND()}/cái",
      ].join(" · ");
    }

    return AppAlertDialog(
      title: isEditMode ? "Sửa linh kiện" : "Thêm linh kiện",
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSearchSelect<Component>(
                label: "Linh kiện",
                hintText: "Chọn linh kiện...",
                items: availableComponents,
                value: component,
                labelOf: (c) => c.name,
                subtitleOf: (c) => [
                  c.category.target?.name,
                  c.type.target?.name,
                ].whereType<String>().join(" · "),
                leadingOf: (c) => ComponentThumbnail.of(c, size: 32),
                onChanged: pickComponent,
              ),

              // --- BIẾN THỂ ---
              if (component != null && component.hasVariants) ...[
                const SizedBox(height: 12),
                if (variants.isEmpty)
                  const Text(
                    "Linh kiện chưa có biến thể nào. Hãy tạo biến thể ở trang Linh kiện.",
                    style: TextStyle(fontSize: 12, color: AppColors.warning),
                  )
                else
                  AppSearchSelect<ComponentVariant>(
                    key: ValueKey(("variant", component.id)),
                    label: "Biến thể",
                    hintText: "Chọn biến thể (VD: 5V · Active)...",
                    items: variants,
                    value: variant,
                    labelOf: (v) => v.labelFor(component.attributes),
                    subtitleOf: variantSubtitle,
                    onChanged: (v) {
                      if (v?.id == selectedVariant.value?.id) return;
                      selectedVariant.value = v;
                    },
                  ),
              ],

              const SizedBox(height: 12),
              AppTextField(
                label: "Số lượng cần (cái)",
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
              ),

              if (variant != null) ...[
                const SizedBox(height: 12),
                AppSearchSelect<ComponentOption>(
                  key: ValueKey(("option", variant.id)),
                  label: "Mua ở đâu",
                  hintText: offers.isEmpty
                      ? "Biến thể này chưa có tùy chọn mua"
                      : "Chọn tùy chọn...",
                  items: offers,
                  value: option,
                  labelOf: (o) => o.displayName,
                  subtitleOf: (o) {
                    final units = o.unitsPerPack <= 0 ? 1 : o.unitsPerPack;
                    final packs = (need + units - 1) ~/ units;
                    return "$packs gói = ${PurchasePlanner.singleCost(o, need).toVND()}"
                        " · ${o.pricePerUnit.toVND()}/cái"
                        "${o.id == best?.id && offers.length > 1 ? "  ★ rẻ nhất cho $need cái" : ""}";
                  },
                  onChanged: (o) {
                    selectedOption.value = o;
                    optionTouched.value = true;
                  },
                ),
                if (offers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "Thêm tuỳ chọn mua cho biến thể này ở trang Linh kiện.",
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
              ],

              const SizedBox(height: 12),
              if (option != null && quantity > 0)
                Text(
                  "Thành tiền: ${(option.pricePerUnit * quantity).toVND()}"
                  "${optionCost != null && optionCost != (option.pricePerUnit * quantity).round() ? "  (phải mua ${(optionCost / option.pricePerPack).round()} gói = ${optionCost.toVND()})" : ""}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (option != null &&
                  best != null &&
                  best.id != option.id &&
                  optionTouched.value)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: InkWell(
                    onTap: () {
                      selectedOption.value = best;
                      optionTouched.value = false;
                    },
                    child: Text(
                      "Rẻ hơn: ${best.displayName} — ${PurchasePlanner.singleCost(best, need).toVND()} cho $need cái. Bấm để chọn.",
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                      ),
                    ),
                  ),
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
              variant == null ||
              option == null ||
              quantity <= 0,
          onPressed: () {
            final item = projectItem ?? ProjectItem();
            item.quantity = quantity;
            item.component.targetId = component!.id;
            item.variant.targetId = variant!.id;
            item.componentOption.targetId = option!.id;
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
