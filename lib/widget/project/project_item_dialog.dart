import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/unit.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/combo_part.dart';
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
import 'package:component_companion/util/component_search.dart';
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

  /// Thêm theo combo (VD 1 cặp XT60 = 1 đực + 1 cái): mỗi thành phần 1 dòng.
  /// null = ẩn chế độ combo.
  final Future<void> Function(List<ProjectItem> items)? onSaveCombo;

  const ProjectItemDialog({
    super.key,
    this.project,
    this.projectOption,
    this.projectItem,
    required this.onSave,
    required this.availableComponents,
    this.onSaveCombo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = projectItem != null;
    final comboMode = useState(false);
    final combos = {
      for (final c in availableComponents)
        for (final o in c.options)
          if (o.isCombo) o.id: o,
    }.values.toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
    final canCombo = !isEditMode && onSaveCombo != null;
    // Giữ id rồi tra lại trong danh sách mới nhất mỗi lần build: danh sách
    // linh kiện được phát lại khi tạo biến thể / tuỳ chọn mua trong dialog
    final componentId = useState<int?>(projectItem?.component.targetId);
    final component = availableComponents
        .where((c) => c.id == componentId.value)
        .firstOrNull;
    final variants = component?.sortedVariants ?? const <ComponentVariant>[];

    final variantId = useState<int?>(projectItem?.variant.targetId);
    // Chuỗi vừa gõ khi tìm linh kiện (để đoán biến thể)
    final lastQuery = useRef("");
    final variant = variants.where((v) => v.id == variantId.value).firstOrNull;

    final unit = variant?.unit ?? component?.quantityUnit ?? QuantityUnit.piece;
    final quantityCtrl = useTextEditingController(
      text: isEditMode ? unit.formatNumber(projectItem!.quantity) : "1",
    );
    final quantity = unit.parse(useValueListenable(quantityCtrl).text) ?? 0;
    final need = quantity <= 0 ? 1 : quantity;

    // Tuỳ chọn mua của biến thể, rẻ nhất theo TỔNG TIỀN cho số lượng cần
    final offers = variant == null
        ? const <ComponentOption>[]
        : (variant.options.toList()..sort((a, b) {
            final byCost =
                PurchasePlanner.singleCost(
                  a,
                  need,
                  variantId: variant.id,
                ).compareTo(
                  PurchasePlanner.singleCost(b, need, variantId: variant.id),
                );
            return byCost != 0
                ? byCost
                : a
                      .unitPriceFor(variant.id)
                      .compareTo(b.unitPriceFor(variant.id));
          }));
    final best = PurchasePlanner.bestSingle(
      offers,
      need,
      variantId: variant?.id,
    );

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
      final picked = availableComponents.where((c) => c.id == id).firstOrNull;
      final list = picked?.sortedVariants ?? const <ComponentVariant>[];
      // Linh kiện chỉ có 1 biến thể (hoặc không có thuộc tính) => chọn luôn;
      // tìm bằng "tụ 100uF" => chọn luôn biến thể 100uF
      variantId.value = list.length == 1
          ? list.first.id
          : picked == null
          ? null
          : ComponentSearch.variantFromQuery(lastQuery.value, picked)?.id;
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
        : PurchasePlanner.singleCost(option, need, variantId: variant?.id);

    String variantSubtitle(ComponentVariant v) {
      final cheapest = PurchasePlanner.bestSingle(
        v.options,
        need,
        variantId: v.id,
      );
      return [
        v.stock == null
            ? "Chưa nhập kho"
            : "Kho: ${v.unit.isPiece ? v.stock : v.unit.format(v.stock!)}",
        if (cheapest != null) "từ ${cheapest.unitPriceText(v.id)}",
      ].join(" · ");
    }

    Widget modeSwitch() => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SegmentedButton<bool>(
        segments: [
          const ButtonSegment(
            value: false,
            label: Text("Từng linh kiện"),
            icon: Icon(Icons.memory_outlined),
          ),
          ButtonSegment(
            value: true,
            label: Text("Theo combo (${combos.length})"),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
        selected: {comboMode.value},
        onSelectionChanged: (v) => comboMode.value = v.first,
      ),
    );

    if (canCombo && comboMode.value) {
      return _ComboAddDialog(
        header: modeSwitch(),
        combos: combos,
        project: project,
        projectOption: projectOption,
        onSave: onSaveCombo!,
      );
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
              if (canCombo) modeSwitch(),
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
                keywordsOf: ComponentSearch.keywords,
                onQueryChanged: (q) => lastQuery.value = q,
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
                label: "Số lượng cần (${unit.label})",
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
                    final raw = o.unitsFor(variant.id);
                    final units = raw <= 0 ? 1 : raw;
                    final packs = (need + units - 1) ~/ units;
                    return "${o.isCombo ? "Combo ${o.contentsLabel} · " : ""}"
                        "$packs ${o.isCombo ? "combo" : "gói"} = ${PurchasePlanner.singleCost(o, need, variantId: variant.id).toVND()}"
                        " · ${o.unitPriceText(variant.id)}"
                        "${o.id == best?.id && offers.length > 1 ? "  ★ rẻ nhất cho ${unit.format(need)}" : ""}";
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
                  "Thành tiền: ${(option.unitPriceFor(variant?.id) * quantity).toVND()}"
                  "${optionCost != null && optionCost != (option.unitPriceFor(variant?.id) * quantity).round() ? "  (phải mua ${(optionCost / option.pricePerPack).round()} ${option.isCombo ? "combo" : "gói"} = ${optionCost.toVND()})" : ""}",
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
                      "Rẻ hơn: ${best.displayName} — ${PurchasePlanner.singleCost(best, need, variantId: variant?.id).toVND()} cho ${unit.format(need)}. Bấm để chọn.",
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
                      ? "Kho đang có ${unit.format(stock)} — đủ dùng"
                      : "Kho đang có ${unit.format(stock)} — thiếu ${unit.format(quantity - stock)}",
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
            // Đóng trước: onSave có thể mở dialog khác (VD báo trùng), đóng
            // sau sẽ đóng nhầm dialog đó
            Navigator.pop(context);
            onSave(item);
          },
        ),
      ],
    );
  }
}

/// Thêm theo combo: dự án tính SỐ CÁI dùng, không phải số combo. Nhập số
/// bộ (1 bộ = tỉ lệ nhỏ nhất giữa các thành phần, VD combo 10 vít + 10 ốc =>
/// 1 bộ = 1 vít + 1 ốc), sửa riêng từng dòng được; tuỳ chọn mua = combo đó
/// (trang Cần mua tự quy ra số combo phải mua).
class _ComboAddDialog extends HookWidget {
  final Widget header;
  final List<ComponentOption> combos;
  final Project? project;
  final ProjectOption? projectOption;
  final Future<void> Function(List<ProjectItem> items) onSave;

  const _ComboAddDialog({
    required this.header,
    required this.combos,
    required this.project,
    required this.projectOption,
    required this.onSave,
  });

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  /// Thành phần còn biến thể / linh kiện kèm số cái trong 1 bộ.
  static List<({ComboPart part, ComponentVariant variant, int perSet})> partsOf(
    ComponentOption? combo,
  ) {
    final list = [
      for (final p in combo?.parts ?? const <ComboPart>[])
        if (p.variant.target case final v? when v.component.target != null)
          (part: p, variant: v),
    ];
    final g = list.fold(0, (g, p) => _gcd(g, p.part.quantity));
    return [
      for (final p in list)
        (
          part: p.part,
          variant: p.variant,
          perSet: g <= 0 ? p.part.quantity : p.part.quantity ~/ g,
        ),
    ];
  }

  static String _name(ComponentVariant v) {
    final c = v.component.target!;
    return v.isDefault ? c.name : "${c.name} · ${v.labelFor(c.attributes)}";
  }

  @override
  Widget build(BuildContext context) {
    final comboId = useState<int?>(combos.length == 1 ? combos.first.id : null);
    final combo = combos.where((o) => o.id == comboId.value).firstOrNull;
    final parts = partsOf(combo);
    final setsCtrl = useTextEditingController(text: "1");
    // Số cái từng dòng (variantId -> số cái); đổi số bộ => tính lại
    final quantities = useState<Map<int, int>>({});
    // Ô số cái từng dòng phải vẽ lại khi đổi số bộ / combo
    final revision = useState(0);
    final saving = useState(false);

    void applySets() {
      final sets = int.tryParse(setsCtrl.text.trim()) ?? 0;
      quantities.value = {for (final p in parts) p.variant.id: p.perSet * sets};
      revision.value++;
    }

    useEffect(() {
      applySets();
      return null;
    }, [combo?.id]);

    int qtyOf(int variantId) => quantities.value[variantId] ?? 0;
    final chosen = [
      for (final p in parts)
        if (qtyOf(p.variant.id) > 0) p,
    ];
    // Số combo phải mua để đủ mọi dòng
    final packs = combo == null
        ? 0
        : parts.fold(0, (m, p) {
            final need = qtyOf(p.variant.id);
            final n = (need + p.part.quantity - 1) ~/ p.part.quantity;
            return n > m ? n : m;
          });

    Future<void> save() async {
      if (combo == null || chosen.isEmpty || saving.value) return;
      saving.value = true;
      await onSave([
        for (final p in chosen)
          ProjectItem(quantity: qtyOf(p.variant.id))
            ..component.targetId = p.variant.component.targetId
            ..variant.targetId = p.variant.id
            ..componentOption.targetId = combo.id
            ..project.targetId = project?.id ?? 0
            ..projectOption.targetId = projectOption?.id ?? 0,
      ]);
      if (context.mounted) Navigator.pop(context);
    }

    final setLabel = parts
        .map((p) => "${p.perSet} ${_name(p.variant)}")
        .join(" + ");

    return AppAlertDialog(
      title: "Thêm linh kiện theo combo",
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              if (combos.isEmpty)
                const Text(
                  "Chưa có combo nào. Tạo ở mục \"Tuỳ chọn mua\" của linh kiện "
                  "(bật \"Combo / bộ\"), VD 1 cặp XT60 = đực ×1 + cái ×1.",
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                )
              else ...[
                AppSearchSelect<ComponentOption>(
                  label: "Combo",
                  hintText: "Chọn combo...",
                  items: combos,
                  value: combo,
                  labelOf: (o) => o.displayName,
                  subtitleOf: (o) =>
                      "${o.contentsLabel} · ${o.pricePerPack.toVND()}",
                  onChanged: (o) => comboId.value = o?.id,
                ),
                if (combo != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Số bộ cần dùng",
                      helperText: "1 bộ = $setLabel",
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => applySets(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Số lượng dùng trong dự án (sửa riêng từng dòng được):",
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  for (final p in parts)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: ComponentThumbnail.of(
                        p.variant.component.target!,
                        size: 32,
                      ),
                      title: Text(_name(p.variant)),
                      subtitle: Text(
                        [
                          "1 combo có ${p.variant.unit.format(p.part.quantity)}",
                          p.variant.stock == null
                              ? "chưa nhập kho"
                              : "kho ${p.variant.unit.isPiece ? p.variant.stock : p.variant.unit.format(p.variant.stock!)}",
                        ].join(" · "),
                      ),
                      trailing: SizedBox(
                        width: 72,
                        child: TextFormField(
                          key: ValueKey((
                            "combo-qty",
                            p.variant.id,
                            revision.value,
                          )),
                          initialValue: p.variant.unit.formatNumber(
                            qtyOf(p.variant.id),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: p.variant.unit.label,
                          ),
                          onChanged: (t) => quantities.value = {
                            ...quantities.value,
                            p.variant.id: p.variant.unit.parse(t) ?? 0,
                          },
                        ),
                      ),
                    ),
                  if (packs > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Cần mua $packs combo = "
                        "${(combo.pricePerPack * packs).toVND()} "
                        "(trang Cần mua tự trừ tồn kho)",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: chosen.isEmpty ? "Thêm" : "Thêm ${chosen.length} linh kiện",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: combo == null || chosen.isEmpty || saving.value,
          onPressed: save,
        ),
      ],
    );
  }
}
