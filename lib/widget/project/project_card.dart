import 'dart:convert';

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:flutter/material.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final Widget projectOptionPriceWidgets;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProjectCard({
    super.key,
    required this.project,
    required this.projectOptionPriceWidgets,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
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
          mainAxisSize: MainAxisSize.min,
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
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: status.color.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

            // --- BODY: Danh sách Options + Giá ---
            if (project.projectOptions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                ),
                child: projectOptionPriceWidgets,
              ),

            // --- FOOTER: Hiển thị thêm thông tin nếu cần ---
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "Tổng số phiên bản: ${project.projectOptions.length}",
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
