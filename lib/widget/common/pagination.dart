import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';

class AppPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChange;

  const AppPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(
          icon: Icons.chevron_left,
          onPressed: currentPage > 0
              ? () => onPageChange(currentPage - 1)
              : null,
        ),

        // --- Hiển thị trang ---
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "${currentPage + 1} / $totalPages",
            style: const TextStyle(
              fontFamily: 'Courier', // Font Monospace để số đứng yên
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),

        _buildButton(
          icon: Icons.chevron_right,
          onPressed: currentPage < totalPages - 1
              ? () => onPageChange(currentPage + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildButton({required IconData icon, VoidCallback? onPressed}) {
    final bool isDisabled = onPressed == null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
          color: isDisabled ? Colors.grey.shade100 : Colors.white,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDisabled ? AppColors.textMuted : AppColors.textMain,
        ),
      ),
    );
  }
}
