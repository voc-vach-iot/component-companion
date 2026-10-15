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
import 'package:component_companion/widget/component/component_action.dart';
import 'package:component_companion/widget/component/component_option_action.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/component/variant_action.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Thêm / sửa linh kiện trong dự án. Thiếu gì (linh kiện, biến thể, tuỳ chọn
/// mua) thì tạo luôn tại chỗ, không phải thoát ra trang khác.
class ProjectItemDialog extends HookConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = projectItem != null;

    // Giữ id rồi tra lại trong danh sách mới nhất mỗi lần build: danh sách
    // linh kiện được phát lại khi tạo biến thể / tuỳ chọn mua trong dialog
    final componentId = useState<int?>(projectItem?.component.targetId);
    final component = availableComponents
        .where((c) => c.id == componentId.value)
        .firstOrNull;
    final variants = component?.sortedVariants ?? const <ComponentVariant>[];

    final variantId = useState<int?>(projectItem?.variant.targetId);
    final variant = variants.where((v) => v.id == variantId.value).firstOrNull;

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

    final optionId = useState<int?>(projectItem?.componentOption.targetId);
    final selectedOption = offers
        .where((o) => o.id == optionId.value)
        .firstOrNull;
    // Người dùng tự chọn tuỳ chọn => không tự đổi sang rẻ nhất nữa
    final optionTouched = useState(isEditMode);

    final offerKey = offers.map((o) => o.id).join(",");
    useEffect(() {
      final valid = selectedOption != null;
      if (!valid || !optionTouched.value) {
        if (best?.id != optionId.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) optionId.value = best?.id;
          });
        }
      }
      return null;
    }, [offerKey, need]);

    void pickComponentId(int id) {
      if (id == componentId.value) return;
      componentId.value = id;
      final list =
          availableComponents
              .where((c) => c.id == id)
              .firstOrNull
              ?.sortedVariants ??
          const [];
      // Linh kiện chỉ có 1 biến thể (hoặc không có thuộc tính) => chọn luôn
      variantId.value = list.length == 1 ? list.first.id : null;
      optionId.value = null;
      optionTouched.value = false;
    }

    Future<void> createComponent(String name) async {
      final id = await ComponentAction.showAdd(context, ref, initialName: name);
      if (id == null || !context.mounted) return;
      componentId.value = id;
      // Linh kiện mới không thuộc tính => có sẵn 1 biến thể mặc định, sẽ
      // được chọn khi danh sách linh kiện cập nhật
      variantId.value = null;
      optionId.value = null;
      optionTouched.value = false;
    }

    Future<void> createVariant() async {
      final id = await VariantAction.showAdd(context, ref, component!);
      if (id == null || !context.mounted) return;
      variantId.value = id;
      optionId.value = null;
      optionTouched.value = false;
    }

    Future<void> createOffer() async {
      final id = await ComponentOptionAction.showAdd(
        context,
        ref,
        component!,
        initialVariantIds: {variant!.id},
      );
      if (id == null || !context.mounted) return;
      optionId.value = id;
      optionTouched.value = true;
    }

    // Linh kiện mới tạo (không thuộc tính) có đúng 1 biến thể => tự chọn
    useEffect(() {
      if (component != null && variant == null && variants.length == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) variantId.value = variants.first.id;
        });
      }
      return null;
    }, [component?.id, variants.length]);

    final stock = variant?.stock;
    final option = selectedOption;
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
                onChanged: (c) {
                  if (c != null) pickComponentId(c.id);
                },
                // Gõ tên chưa có => tạo linh kiện mới với tên đó
                onCreate: createComponent,
              ),
              if (component == null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => createComponent(""),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Linh kiện mới"),
                  ),
                ),

              // --- BIẾN THỂ ---
              if (component != null && component.hasVariants) ...[
                const SizedBox(height: 12),
                if (variants.isEmpty)
                  const Text(
                    "Linh kiện chưa có biến thể nào.",
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
                      if (v?.id == variantId.value) return;
                      variantId.value = v?.id;
                    },
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: createVariant,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Biến thể mới"),
                  ),
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
                    optionId.value = o?.id;
                    optionTouched.value = true;
                  },
                ),
                Row(
                  children: [
                    if (offers.isEmpty)
                      const Expanded(
                        child: Text(
                          "Biến thể này chưa có tuỳ chọn mua.",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    TextButton.icon(
                      onPressed: createOffer,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Tuỳ chọn mua mới"),
                    ),
                  ],
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
                      optionId.value = best.id;
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
