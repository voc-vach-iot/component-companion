import 'dart:convert';
import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:flutter/material.dart';

class ProjectItemCard extends StatelessWidget {
  final ProjectItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProjectItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  // Thay thế đoạn build cũ bằng đoạn này
  @override
  Widget build(BuildContext context) {
    final component = item.component.target;
    final option = item.componentOption.target;
    final pricePerUnit =
        (option?.pricePerPack ?? 0) / (option?.unitsPerPack ?? 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // 1. Ảnh (Không bọc Expanded, để cố định width)
          _buildThumbnail(component?.base64Image),
          const SizedBox(width: 16),

          // 2. Tên & Quy cách (Expanded là con trực tiếp của Row)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component?.name ?? "Linh kiện",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  option?.name ?? "Chưa chọn quy cách",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // 3. Giá chi tiết (Expanded là con trực tiếp của Row)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${pricePerUnit.toVND()}/cái",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  "${(option?.pricePerPack ?? 0).toVND()}/gói",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // 4. Số lượng (Expanded là con trực tiếp của Row)
          Expanded(
            flex: 1,
            child: Text(
              "x${item.quantity}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          // 5. Tổng tiền (Expanded là con trực tiếp của Row)
          Expanded(
            flex: 1,
            child: Text(
              item.totalPrice.toVND(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),

          // 6. Buttons (Không bọc Expanded)
          const SizedBox(width: 16),
          Row(
            children: [
              AppActionButton(actionType: ActionType.edit, onTap: onEdit),
              AppActionButton(actionType: ActionType.delete, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? base64String) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: (base64String != null && base64String.isNotEmpty)
            ? Image.memory(base64Decode(base64String), fit: BoxFit.cover)
            : const Icon(Icons.memory, size: 20, color: AppColors.textDisabled),
      ),
    );
  }
}
