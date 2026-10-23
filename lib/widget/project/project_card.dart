import 'dart:convert';

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/highlight_text.dart';
import 'package:component_companion/widget/project/project_stock_tag.dart';
import 'package:flutter/material.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Tô sáng phần khớp với ô tìm kiếm.
  final TextSearch? search;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.search,
  });

  Widget _buildThumbnail(String base64String) {
    if (base64String.isEmpty) {
      return const Center(
        child: Icon(Icons.folder_open, color: AppColors.textDisabled, size: 24),
      );
    }
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(base64String),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
        ),
      );
    } catch (e) {
      return const Center(child: Icon(Icons.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = project.projectStatus;
    final groups = project.sortedGroups;
    final items = project.configurationItems;
    final range = project.configurationPriceRange();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      mouseCursor: SystemMouseCursors.click,
      child: Container(
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
          children: [
            // --- HEADER: Ảnh + Tên + Trạng thái + Actions ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildThumbnail(project.base64Image),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HighlightText(
                          project.name,
                          search: search,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: status.color,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    status.icon,
                                    size: 12,
                                    color: status.foreground,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    status.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: status.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ProjectStockTag(
                              projectId: project.id,
                              status: status,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppActionButton(actionType: ActionType.edit, onTap: onEdit),
                  const SizedBox(width: 4),
                  AppActionButton(
                    actionType: ActionType.delete,
                    onTap: onDelete,
                  ),
                ],
              ),
            ),

            // --- BODY: Cấu hình đang chọn (phương án của từng nhóm) ---
            Expanded(
              child: groups.isEmpty
                  ? const Center(
                      child: Text(
                        "Chưa có nhóm lựa chọn",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      children: [
                        for (final g in groups)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.alt_route_rounded,
                                  size: 14,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: "${g.name}: ",
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              g.selectedOption?.name ??
                                              "(chưa có phương án)",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (g.options.length > 1)
                                          TextSpan(
                                            text:
                                                "  / ${g.options.length} phương án",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textDisabled,
                                            ),
                                          ),
                                      ],
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

            // --- FOOTER: Tổng tiền cấu hình đang chọn ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        "${items.length} linh kiện",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        project.configurationPrice.toVND(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (range.max - range.min >= 1)
                    Text(
                      "Các cấu hình: ${range.min.toVND()} – ${range.max.toVND()}",
                      textAlign: TextAlign.right,
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
          ],
        ),
      ),
    );
  }
}
