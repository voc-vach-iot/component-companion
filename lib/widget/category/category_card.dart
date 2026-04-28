import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/widget/button/action_button.dart';
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    category.name,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                // Các nút Actions nằm ở đây
                Row(
                  children: [
                    AppActionButton(actionType: ActionType.edit, onTap: onEdit),
                    AppActionButton(
                      actionType: ActionType.delete,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- BODY: Nội dung chính ---
          Expanded(
            child: InkWell(
              child: Center(
                child: Icon(category.icon, color: category.color, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
