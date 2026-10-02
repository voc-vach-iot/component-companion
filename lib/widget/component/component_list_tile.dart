import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/highlight_text.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:flutter/material.dart';

/// 1 dòng trong danh sách linh kiện (bên trái trang linh kiện).
class ComponentListTile extends StatelessWidget {
  static const double height = 64;

  final Component component;
  final bool selected;
  final VoidCallback onTap;
  final TextSearch? search;

  const ComponentListTile({
    super.key,
    required this.component,
    required this.selected,
    required this.onTap,
    this.search,
  });

  @override
  Widget build(BuildContext context) {
    final category = component.category.target;
    final type = component.type.target;
    final variantCount = component.variants.length;
    final stock = component.stockTotal;
    final out = component.outCount;
    final low = component.lowCount;
    final cheapest = ComponentRepository.cheapestUnitPrice(component);

    final subtitle = [
      category?.name ?? "Chưa phân loại",
      if (type != null) type.name,
      if (component.hasVariants) "$variantCount biến thể",
    ].join(" · ");

    final stockColor = out > 0
        ? AppColors.error
        : low > 0
        ? AppColors.warning
        : AppColors.textMuted;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.35)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                ComponentThumbnail.of(component, category: category, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HighlightText(
                        component.name,
                        search: search,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: [
                        if (out > 0) "$out biến thể hết hàng",
                        if (low > 0) "$low biến thể sắp hết",
                      ].join("\n"),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (out > 0 || low > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 13,
                                color: stockColor,
                              ),
                            ),
                          Text(
                            stock == null ? "Chưa nhập kho" : "Kho: $stock",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: stock == null
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                              color: stock == null
                                  ? AppColors.textDisabled
                                  : stockColor == AppColors.textMuted
                                  ? AppColors.textMain
                                  : stockColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (cheapest != null)
                      Text(
                        "từ ${cheapest.toVND()}/cái",
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
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
