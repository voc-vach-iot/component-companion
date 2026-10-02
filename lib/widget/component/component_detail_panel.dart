import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/hook/use_page_effect.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/util/price_insight.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/highlight_text.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/component/component_action.dart';
import 'package:component_companion/widget/component/component_option_action.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/component/variant_action.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/view/grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Chi tiết 1 linh kiện: biến thể + tồn kho, các tuỳ chọn mua theo shop.
class ComponentDetailPanel extends HookConsumerWidget {
  final int componentId;
  final TextSearch? search;

  /// Linh kiện mới (nhân bản) cần chọn.
  final ValueChanged<int> onSelect;

  const ComponentDetailPanel({
    super.key,
    required this.componentId,
    required this.onSelect,
    this.search,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final componentAsync = useKeepPreviousData(
      ref.watch(watchComponentProvider(componentId)),
    );
    // Lọc tuỳ chọn mua theo biến thể đang chọn (null = tất cả)
    final variantFilter = useState<int?>(null);
    // Tuỳ chọn / biến thể vừa thêm => nháy sáng
    final flashOption = useState<int?>(null);
    final flashVariant = useState<int?>(null);

    void flash(ValueNotifier<int?> target, int id) {
      target.value = id;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (context.mounted && target.value == id) target.value = null;
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: componentAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, s) => AppErrorView(message: "Lỗi tải linh kiện: $e"),
        data: (component) {
          if (component == null) {
            return const Center(
              child: Text(
                "Linh kiện không còn tồn tại",
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          final variants = component.sortedVariants;
          final filterId = variants.any((v) => v.id == variantFilter.value)
              ? variantFilter.value
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                component: component,
                search: search,
                onEdit: () => ComponentAction.showEdit(context, ref, component),
                onClone: () => ComponentAction.clone(
                  context,
                  ref,
                  component,
                  onSuccess: onSelect,
                ),
                onDelete: () =>
                    ComponentAction.showDelete(context, ref, component),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _VariantSection(
                      component: component,
                      variants: variants,
                      selectedId: filterId,
                      flashId: flashVariant.value,
                      onSelect: (id) => variantFilter.value =
                          variantFilter.value == id ? null : id,
                      onAdded: (id) => flash(flashVariant, id),
                    ),
                    const SizedBox(height: 24),
                    _OfferSection(
                      component: component,
                      variants: variants,
                      filterId: filterId,
                      flashId: flashOption.value,
                      onClearFilter: () => variantFilter.value = null,
                      onAdded: (id) => flash(flashOption, id),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final Component component;
  final TextSearch? search;
  final VoidCallback onEdit;
  final VoidCallback onClone;
  final VoidCallback onDelete;

  const _Header({
    required this.component,
    required this.search,
    required this.onEdit,
    required this.onClone,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final category = component.category.target;
    final type = component.type.target;
    final categoryColor = category?.color ?? AppColors.primary;
    final attributes = component.attributes;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.18),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ComponentThumbnail.of(component, category: category, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HighlightText(
                  component.name,
                  search: search,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(
                      category?.name ?? "Chưa phân loại",
                      color: categoryColor.withValues(alpha: 0.5),
                    ),
                    if (type != null)
                      _Pill(type.name, color: AppColors.surfaceVariant),
                    for (final a in attributes)
                      Tooltip(
                        message: a.values.join(", "),
                        child: _Pill(
                          "${a.name}: ${a.values.length} giá trị",
                          color: AppColors.info.withValues(alpha: 0.12),
                        ),
                      ),
                  ],
                ),
                if (component.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    component.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppActionButton(
            icon: Icons.copy_rounded,
            tooltip: "Nhân bản linh kiện (kèm biến thể, tuỳ chọn mua)",
            onTap: onClone,
          ),
          const SizedBox(width: 4),
          AppActionButton(actionType: ActionType.edit, onTap: onEdit),
          const SizedBox(width: 4),
          AppActionButton(actionType: ActionType.delete, onTap: onDelete),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Biến thể & tồn kho
// ---------------------------------------------------------------------------

class _VariantSection extends ConsumerWidget {
  final Component component;
  final List<ComponentVariant> variants;
  final int? selectedId;
  final int? flashId;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onAdded;

  const _VariantSection({
    required this.component,
    required this.variants,
    required this.selectedId,
    required this.flashId,
    required this.onSelect,
    required this.onAdded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasVariants = component.hasVariants;
    final total = component.stockTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          icon: Icons.inventory_2_outlined,
          title: hasVariants ? "Biến thể & tồn kho" : "Tồn kho",
          info: [
            if (hasVariants) "${variants.length} biến thể",
            if (total != null) "tổng $total cái",
          ].join(" · "),
          actions: [
            if (hasVariants) ...[
              TextButton.icon(
                onPressed: () =>
                    VariantAction.showBulkAdd(context, ref, component),
                icon: const Icon(Icons.grid_view_rounded, size: 16),
                label: const Text("Tạo nhiều"),
              ),
              TextButton.icon(
                onPressed: () => VariantAction.showAdd(
                  context,
                  ref,
                  component,
                  onSuccess: onAdded,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Thêm biến thể"),
              ),
            ],
          ],
        ),
        if (hasVariants && variants.length > 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              "Bấm vào 1 biến thể để chỉ xem tuỳ chọn mua của nó.",
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        if (variants.isEmpty)
          _EmptyBox(
            message: hasVariants
                ? "Chưa có biến thể nào. Tạo các biến thể bạn đang có / hay mua "
                      "(VD: 5V · Active) để nhập kho và gắn giá."
                : "Chưa có dữ liệu tồn kho.",
            action: hasVariants
                ? TextButton.icon(
                    onPressed: () =>
                        VariantAction.showBulkAdd(context, ref, component),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Tạo biến thể"),
                  )
                : null,
          )
        else ...[
          const _VariantHeaderRow(),
          for (final v in variants)
            _flashIf(
              v.id == flashId,
              ValueKey(("variant", v.id)),
              _VariantRow(
                component: component,
                variant: v,
                selected: v.id == selectedId,
                selectable: hasVariants && variants.length > 1,
                onTap: () => onSelect(v.id),
              ),
            ),
        ],
      ],
    );
  }
}

class _VariantHeaderRow extends StatelessWidget {
  const _VariantHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(10, 4, 4, 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text("BIẾN THỂ", style: style)),
          SizedBox(
            width: 130,
            child: Text("TỒN KHO", style: style, textAlign: TextAlign.center),
          ),
          Expanded(flex: 2, child: Text("VỊ TRÍ", style: style)),
          Expanded(flex: 3, child: Text("GIÁ RẺ NHẤT", style: style)),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _VariantRow extends ConsumerWidget {
  final Component component;
  final ComponentVariant variant;
  final bool selected;
  final bool selectable;
  final VoidCallback onTap;

  const _VariantRow({
    required this.component,
    required this.variant,
    required this.selected,
    required this.selectable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = variant.options.toList()
      ..sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
    final cheapest = offers.firstOrNull;
    final stock = variant.stock;
    final stockColor = variant.isOut
        ? AppColors.error
        : variant.isLow
        ? AppColors.warning
        : AppColors.textMain;
    final label = variant.labelFor(component.attributes);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? AppColors.info.withValues(alpha: 0.12)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: selectable ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.info : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                // --- Nhãn ---
                Expanded(
                  flex: 3,
                  child: Tooltip(
                    message: [
                      label,
                      if (variant.note.isNotEmpty) variant.note,
                    ].join("\n"),
                    child: Text(
                      component.hasVariants ? label : component.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                // --- Tồn kho ---
                SizedBox(
                  width: 130,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StockButton(
                        icon: Icons.remove_rounded,
                        tooltip: "Bớt 1",
                        onTap: (stock ?? 0) > 0
                            ? () => VariantAction.adjustStock(
                                context,
                                ref,
                                variant,
                                -1,
                              )
                            : null,
                      ),
                      InkWell(
                        onTap: () => VariantAction.showEdit(
                          context,
                          ref,
                          component,
                          variant,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Tooltip(
                          message: stock == null
                              ? "Chưa theo dõi kho. Bấm + để bắt đầu, hoặc bấm vào đây để nhập số lượng."
                              : variant.lowStockThreshold > 0
                              ? "Cảnh báo khi còn ≤ ${variant.lowStockThreshold}"
                              : "Bấm để sửa số lượng",
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              stock?.toString() ?? "—",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: stock == null
                                    ? AppColors.textDisabled
                                    : stockColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _StockButton(
                        icon: Icons.add_rounded,
                        tooltip: "Thêm 1",
                        onTap: () =>
                            VariantAction.adjustStock(context, ref, variant, 1),
                      ),
                    ],
                  ),
                ),

                // --- Vị trí ---
                Expanded(
                  flex: 2,
                  child: Text(
                    variant.location.isEmpty ? "—" : variant.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: variant.location.isEmpty
                          ? AppColors.textDisabled
                          : AppColors.textMain,
                    ),
                  ),
                ),

                // --- Giá rẻ nhất ---
                Expanded(
                  flex: 3,
                  child: cheapest == null
                      ? const Text(
                          "Chưa có tuỳ chọn mua",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textDisabled,
                          ),
                        )
                      : Tooltip(
                          message: cheapest.displayName,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "${cheapest.pricePerUnit.toVND()}/cái",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      "  ${cheapest.shopName.isEmpty ? cheapest.name : cheapest.shopName}"
                                      "${offers.length > 1 ? " · ${offers.length} lựa chọn" : ""}",
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                ),

                // --- Menu ---
                SizedBox(
                  width: 40,
                  child: PopupMenuButton<VoidCallback>(
                    tooltip: "Thao tác",
                    icon: const Icon(Icons.more_vert, size: 18),
                    color: AppColors.background,
                    onSelected: (action) => action(),
                    itemBuilder: (context) => [
                      _menuItem(
                        Icons.edit_outlined,
                        "Sửa (tồn kho, vị trí, ...)",
                        () => VariantAction.showEdit(
                          context,
                          ref,
                          component,
                          variant,
                        ),
                      ),
                      if (component.hasVariants)
                        _menuItem(
                          Icons.delete_outline,
                          "Xoá biến thể",
                          () => VariantAction.showDelete(context, ref, variant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _StockButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.6),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tuỳ chọn mua theo shop
// ---------------------------------------------------------------------------

class _OfferSection extends ConsumerWidget {
  final Component component;
  final List<ComponentVariant> variants;
  final int? filterId;
  final int? flashId;
  final VoidCallback onClearFilter;
  final ValueChanged<int> onAdded;

  const _OfferSection({
    required this.component,
    required this.variants,
    required this.filterId,
    required this.flashId,
    required this.onClearFilter,
    required this.onAdded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = component.options.toList()
      ..sort((a, b) {
        final byPrice = a.pricePerUnit.compareTo(b.pricePerUnit);
        return byPrice != 0 ? byPrice : a.id.compareTo(b.id);
      });
    final shown = filterId == null
        ? all
        : all.where((o) => o.appliesTo(filterId!)).toList();
    final cheapestId = shown.length > 1 ? shown.first.id : null;
    final filterVariant = variants.where((v) => v.id == filterId).firstOrNull;

    // Nhóm theo shop, nhóm có đơn giá rẻ nhất lên trước (đã sắp sẵn)
    final groups = <int, List<ComponentOption>>{};
    for (final o in shown) {
      groups.putIfAbsent(o.shop.targetId, () => []).add(o);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          icon: Icons.sell_outlined,
          title: "Tuỳ chọn mua",
          info: filterId == null
              ? "${all.length} tuỳ chọn · ${groups.length} shop"
              : "${shown.length}/${all.length} tuỳ chọn",
          actions: [
            if (filterVariant != null)
              InputChip(
                label: Text(
                  "Biến thể: ${filterVariant.labelFor(component.attributes)}",
                ),
                visualDensity: VisualDensity.compact,
                onDeleted: onClearFilter,
                deleteButtonTooltipMessage: "Xem tất cả",
              ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: component.hasVariants && variants.isEmpty
                  ? () => AppSnackBar.show(
                      context,
                      message: "Hãy tạo biến thể trước khi thêm tuỳ chọn mua",
                      type: SnackBarType.info,
                    )
                  : () => ComponentOptionAction.showAdd(
                      context,
                      ref,
                      component,
                      initialVariantIds: {?filterId},
                      onSuccess: onAdded,
                    ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Thêm tuỳ chọn"),
            ),
          ],
        ),
        if (shown.isEmpty)
          _EmptyBox(
            message: filterId == null
                ? "Chưa có tuỳ chọn mua. Thêm giá của các shop để so sánh."
                : "Biến thể này chưa có tuỳ chọn mua.",
          )
        else
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      entry.value.first.shopName.isEmpty
                          ? "Chưa ghi shop"
                          : entry.value.first.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${entry.value.length} tuỳ chọn",
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            for (final o in entry.value)
              _flashIf(
                o.id == flashId,
                ValueKey(("offer", o.id)),
                _OfferRow(
                  component: component,
                  option: o,
                  allVariantCount: variants.length,
                  isCheapest: o.id == cheapestId,
                ),
              ),
          ],
      ],
    );
  }
}

class _OfferRow extends ConsumerWidget {
  final Component component;
  final ComponentOption option;
  final int allVariantCount;
  final bool isCheapest;

  const _OfferRow({
    required this.component,
    required this.option,
    required this.allVariantCount,
    required this.isCheapest,
  });

  Future<void> _openLink(BuildContext context) async {
    final url = Uri.tryParse(option.link);
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      AppSnackBar.show(
        context,
        message: "Không thể mở liên kết",
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = PriceInsight.of(option);
    final attributes = component.attributes;
    final applied = option.variants.toList();
    final appliedLabels = [
      for (final v in component.sortedVariants)
        if (applied.any((a) => a.id == v.id)) v.labelFor(attributes),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () =>
              ComponentOptionAction.showEdit(context, ref, component, option),
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCheapest
                    ? AppColors.success.withValues(alpha: 0.6)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                // --- Quy cách + áp dụng cho ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          if (isCheapest)
                            const _Tag(
                              "Rẻ nhất",
                              AppColors.success,
                              Icons.star,
                            ),
                          if (insight.trend != null)
                            _Tag(
                              insight.trendLabel!,
                              insight.trend! > 0
                                  ? AppColors.error
                                  : AppColors.success,
                              insight.trend! > 0
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              tooltip: insight.trendTooltip,
                            ),
                          if (insight.isStale)
                            _Tag(
                              insight.staleLabel,
                              AppColors.warning,
                              Icons.schedule,
                              tooltip:
                                  "Giá có thể đã thay đổi. Kiểm tra lại trên shop rồi chọn \"Giá vẫn vậy\".",
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- Biến thể áp dụng (rút gọn, di chuột để xem hết) ---
                if (component.hasVariants)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _AppliesTo(
                        labels: appliedLabels,
                        all: appliedLabels.length == allVariantCount,
                      ),
                    ),
                  ),

                // --- Giá ---
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      option.pricePerPack.toVND(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${option.unitsPerPack} cái · ${option.pricePerUnit.toVND()}/cái",
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),

                // --- Thao tác ---
                PopupMenuButton<VoidCallback>(
                  tooltip: "Thao tác",
                  icon: const Icon(Icons.more_vert, size: 18),
                  color: AppColors.background,
                  onSelected: (action) => action(),
                  itemBuilder: (context) => [
                    _menuItem(
                      Icons.check_circle_outline,
                      "Giá vẫn vậy (đã kiểm tra hôm nay)",
                      () => ComponentOptionAction.confirmPrice(
                        context,
                        ref,
                        option,
                      ),
                    ),
                    _menuItem(
                      Icons.show_chart,
                      "Lịch sử giá",
                      () => ComponentOptionAction.showHistory(context, option),
                    ),
                    if (option.link.isNotEmpty)
                      _menuItem(
                        LucideIcons.externalLink,
                        "Mở link shop",
                        () => _openLink(context),
                      ),
                    _menuItem(
                      Icons.copy_rounded,
                      "Nhân bản",
                      () => ComponentOptionAction.clone(
                        context,
                        ref,
                        component,
                        option,
                      ),
                    ),
                    _menuItem(
                      Icons.edit_outlined,
                      "Sửa",
                      () => ComponentOptionAction.showEdit(
                        context,
                        ref,
                        component,
                        option,
                      ),
                    ),
                    _menuItem(
                      Icons.delete_outline,
                      "Xoá",
                      () => ComponentOptionAction.showDelete(
                        context,
                        ref,
                        option,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Các biến thể 1 tuỳ chọn áp dụng: 1 dòng, cắt bớt nếu dài, tooltip đầy đủ.
class _AppliesTo extends StatelessWidget {
  final List<String> labels;
  final bool all;

  const _AppliesTo({required this.labels, required this.all});

  @override
  Widget build(BuildContext context) {
    final color = labels.isEmpty ? AppColors.error : AppColors.info;
    final text = labels.isEmpty
        ? "Chưa gắn biến thể"
        : all
        ? "Mọi biến thể"
        : labels.join(", ");
    return Tooltip(
      message: labels.isEmpty ? text : "Áp dụng cho:\n${labels.join("\n")}",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_outlined, size: 12, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thành phần chung
// ---------------------------------------------------------------------------

Widget _flashIf(bool flash, Key key, Widget child) => flash
    ? FocusFlash(key: key, borderRadius: BorderRadius.circular(8), child: child)
    : KeyedSubtree(key: key, child: child);

PopupMenuItem<VoidCallback> _menuItem(
  IconData icon,
  String label,
  VoidCallback action,
) => PopupMenuItem(
  value: action,
  height: 40,
  child: Row(
    children: [
      Icon(icon, size: 18, color: AppColors.textMuted),
      const SizedBox(width: 10),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    ],
  ),
);

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String info;
  final List<Widget> actions;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.info = "",
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            info,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class _EmptyBox extends StatelessWidget {
  final String message;
  final Widget? action;

  const _EmptyBox({required this.message, this.action});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        ?action,
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill(this.label, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final String? tooltip;

  const _Tag(this.label, this.color, this.icon, {this.tooltip});

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? tag : Tooltip(message: tooltip!, child: tag);
  }
}
