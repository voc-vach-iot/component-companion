import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/constant/app_svgs.dart';
import 'package:component_companion/extension/color/color.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/highlight_text.dart';
import 'package:flutter/material.dart';

class ComponentTypeCard extends StatelessWidget {
  final ComponentType type;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Tô sáng phần khớp với ô tìm kiếm.
  final TextSearch? search;

  const ComponentTypeCard({
    super.key,
    required this.type,
    required this.onEdit,
    required this.onDelete,
    this.search,
  });

  @override
  Widget build(BuildContext context) {
    final category = type.category.target;
    final color = category?.color ?? AppColors.surfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // --- HEADER ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: HighlightText(
                      type.name,
                      search: search,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                AppActionButton(actionType: ActionType.edit, onTap: onEdit),
                AppActionButton(actionType: ActionType.delete, onTap: onDelete),
              ],
            ),
          ),

          // --- BODY ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      // Viền màu danh mục bao quanh icon, giống khi hiển thị linh kiện
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color, width: 2),
                        ),
                        child: AppSvgIcon(
                          svg: type.defaultIconSvg,
                          fallbackSvg: AppSvgs.chip,
                          size: 40,
                          color: color.onPastel,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category?.name ?? "Chưa gắn danh mục",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: type.keywords.join(", "),
                    child: Text(
                      "${type.keywords.length} từ khóa",
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
