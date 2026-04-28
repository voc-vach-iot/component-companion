import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';

class SelectableWidget extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;

  const SelectableWidget({
    super.key,
    required this.child,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          // Chỉ áp dụng style khi được chọn
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: AppColors.transparent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        // Sử dụng child để bao bọc item gốc
        child: child,
      ),
    );
  }
}
