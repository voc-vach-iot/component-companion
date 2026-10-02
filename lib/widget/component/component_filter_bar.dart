import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/constant/app_svgs.dart';
import 'package:component_companion/extension/color/color.dart';
import 'package:component_companion/model/search_params/component_search_params.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/notifier/component_type_notifier.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Thanh lọc + sắp xếp danh sách linh kiện.
class ComponentFilterBar extends ConsumerWidget {
  final ComponentSearchParams params;
  final ValueChanged<ComponentSearchParams> onChanged;

  /// Tổng số linh kiện khớp bộ lọc (null khi đang tải).
  final int? total;

  const ComponentFilterBar({
    super.key,
    required this.params,
    required this.onChanged,
    this.total,
  });

  static const _noneId = 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(watchAllCategoriesProvider()).value ?? [];
    final types = ref.watch(watchAllComponentTypesProvider()).value ?? [];
    final categoryById = {for (final c in categories) c.id: c};
    final typeById = {for (final t in types) t.id: t};

    // Đổi bộ lọc => quay về trang đầu
    void update(ComponentSearchParams next) =>
        onChanged(next.copyWith(page: 0));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppFilterSelect<int>(
          label: "Danh mục",
          icon: Icons.category_outlined,
          items: [_noneId, ...categories.map((c) => c.id)],
          selected: params.categoryIds.toSet(),
          labelOf: (id) => categoryById[id]?.name ?? "Chưa phân loại",
          leadingOf: (id) {
            final c = categoryById[id];
            return c == null
                ? const Icon(Icons.help_outline, size: 18)
                : AppSvgIcon(
                    svg: c.iconSvg,
                    size: 18,
                    tint: true,
                    color: c.color.onPastel,
                  );
          },
          onChanged: (ids) =>
              update(params.copyWith(categoryIds: ids.toList())),
        ),
        AppFilterSelect<int>(
          label: "Loại",
          icon: Icons.memory_outlined,
          items: [_noneId, ...types.map((t) => t.id)],
          selected: params.typeIds.toSet(),
          labelOf: (id) => typeById[id]?.name ?? "Chưa xác định loại",
          subtitleOf: (id) => typeById[id]?.category.target?.name,
          leadingOf: (id) {
            final t = typeById[id];
            return t == null
                ? const Icon(Icons.help_outline, size: 18)
                : AppSvgIcon(
                    svg: t.defaultIconSvg,
                    fallbackSvg: AppSvgs.chip,
                    size: 18,
                  );
          },
          onChanged: (ids) => update(params.copyWith(typeIds: ids.toList())),
        ),
        _MenuChip<StockFilter>(
          icon: Icons.inventory_2_outlined,
          label: params.stockFilter == StockFilter.all
              ? "Tồn kho"
              : params.stockFilter.label,
          active: params.stockFilter != StockFilter.all,
          values: StockFilter.values,
          selected: params.stockFilter,
          labelOf: (f) => f.label,
          onSelected: (f) => update(params.copyWith(stockFilter: f)),
        ),
        _MenuChip<ComponentSort>(
          icon: Icons.sort_rounded,
          label: params.sort.label,
          active: params.sort != ComponentSort.added,
          values: ComponentSort.values,
          selected: params.sort,
          labelOf: (s) => s.label,
          onSelected: (s) => update(params.copyWith(sort: s)),
        ),
        if (params.hasFilter)
          TextButton.icon(
            onPressed: () => update(
              params.copyWith(
                categoryIds: const [],
                typeIds: const [],
                stockFilter: StockFilter.all,
              ),
            ),
            icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
            label: const Text("Xoá lọc"),
          ),
        if (total != null)
          Text(
            "$total linh kiện",
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

/// Chip mở menu chọn 1 giá trị.
class _MenuChip<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  const _MenuChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.background),
      ),
      menuChildren: [
        for (final value in values)
          MenuItemButton(
            leadingIcon: Icon(
              value == selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: value == selected ? AppColors.info : AppColors.textMuted,
            ),
            onPressed: () => onSelected(value),
            child: Text(labelOf(value)),
          ),
      ],
      builder: (context, controller, _) => FilterChip(
        avatar: Icon(
          icon,
          size: 16,
          color: active ? AppColors.textMain : AppColors.textMuted,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
        showCheckmark: false,
        selected: active,
        selectedColor: AppColors.primary.withValues(alpha: 0.35),
        backgroundColor: AppColors.background,
        side: BorderSide(color: active ? AppColors.primary : AppColors.border),
        onSelected: (_) =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
