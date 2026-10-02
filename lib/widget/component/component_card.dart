import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/component/stock_chip.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/highlight_text.dart';
import 'package:flutter/material.dart';

class ComponentCard extends StatelessWidget {
  final Component component;
  final Category? category;
  final VoidCallback onEditComponent;
  final VoidCallback onDeleteComponent;
  final VoidCallback onCloneComponent;
  final VoidCallback onEditStock;
  final VoidCallback onAddOption;
  final Widget componentOptionsWidget;

  /// Tô sáng phần khớp với ô tìm kiếm.
  final TextSearch? search;

  const ComponentCard({
    super.key,
    required this.component,
    required this.category,
    required this.onEditComponent,
    required this.onDeleteComponent,
    required this.onCloneComponent,
    required this.onEditStock,
    required this.componentOptionsWidget,
    required this.onAddOption,
    this.search,
  });
  @override
  Widget build(BuildContext context) {
    // Lấy màu từ category nếu có, nếu không thì dùng màu mặc định
    final categoryColor = category?.color ?? AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- HEADER: Ảnh + Tên (kèm tag danh mục, loại) + Actions ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.2), // Header màu pastel
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                // Image Thumbnail (ảnh > icon SVG > icon mặc định của loại)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ComponentThumbnail.of(component, category: category),
                ),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Category Tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              category?.name ?? "Chưa phân loại",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (component.type.target != null)
                            Text(
                              component.type.target!.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          if (component.hasVariants)
                            Tooltip(
                              message: [
                                for (final a in component.attributes)
                                  "${a.name}: ${a.values.join(", ")}",
                              ].join("\n"),
                              child: Text(
                                "· ${Variants.combinations(component.attributes, max: 999).length} biến thể",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          StockChip(component: component, onTap: onEditStock),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppActionButton(
                  icon: Icons.copy_rounded,
                  tooltip: "Nhân bản linh kiện (kèm tuỳ chọn)",
                  onTap: onCloneComponent,
                ),
                const SizedBox(width: 4),
                AppActionButton(
                  actionType: ActionType.edit,
                  onTap: onEditComponent,
                ),
                const SizedBox(width: 4),
                AppActionButton(
                  actionType: ActionType.delete,
                  onTap: onDeleteComponent,
                ),
              ],
            ),
          ),

          // --- BODY (Danh sách Options chiếm không gian còn lại) ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: componentOptionsWidget,
            ),
          ),

          // --- FOOTER (Nút Thêm cố định ở dưới cùng) ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                label: "Thêm tuỳ chọn",
                onPressed: onAddOption,
                variant: ButtonVariant.primary,
                size: ButtonSize.small,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
