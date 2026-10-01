import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/color/color.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:flutter/material.dart';

class CategoryCard extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Category category;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // --- HEADER: Title + Actions ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: category.color, // Header màu pastel
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                // Các nút Actions nằm ở đây
                AppActionButton(actionType: ActionType.edit, onTap: onEdit),
                AppActionButton(actionType: ActionType.delete, onTap: onDelete),
              ],
            ),
          ),

          // --- BODY: Nội dung chính ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AppSvgIcon(
                        svg: category.iconSvg,
                        size: 44,
                        tint: true,
                        color: category.color.onPastel,
                      ),
                    ),
                  ),
                  if (category.description.isNotEmpty)
                    Text(
                      category.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Tooltip(
                    message: category.keywords.join(", "),
                    child: Text(
                      "${category.keywords.length} từ khóa",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
