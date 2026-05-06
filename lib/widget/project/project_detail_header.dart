import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:flutter/material.dart';

class ProjectDetailHeader extends StatelessWidget {
  final Project? project;
  final VoidCallback onBack;
  final VoidCallback onAddOption; // Thêm callback này

  const ProjectDetailHeader({
    super.key,
    required this.project,
    required this.onBack,
    required this.onAddOption, // Yêu cầu truyền khi khởi tạo
  });

  @override
  Widget build(BuildContext context) {
    final projectName = project?.name ?? "Dự án không tồn tại";

    String projectDescription = project?.description ?? "Không có mô tả.";
    if (projectDescription.isEmpty) {
      projectDescription = "Không có mô tả.";
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            // Dùng Expanded để đẩy nút Thêm ra sát cạnh phải
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  projectName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  projectDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Nút thêm Option
          AppButton(
            onPressed: onAddOption,
            label: "Thêm tuỳ chọn",
            icon: Icons.add,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );
  }
}
