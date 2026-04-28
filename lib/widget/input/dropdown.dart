import 'package:flutter/material.dart';
import 'package:component_companion/constant/app_colors.dart';

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const AppDropdown({
    super.key,
    required this.label,
    required this.initialValue,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.border, width: 2.0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        ButtonTheme(
          alignedDropdown: true,
          child: DropdownButtonFormField<T>(
            initialValue: initialValue,
            items: items,
            onChanged: onChanged,
            dropdownMenuItemMouseCursor: SystemMouseCursors.click,
            style: const TextStyle(color: AppColors.textMain, fontSize: 15),
            dropdownColor: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            mouseCursor: SystemMouseCursors.click,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: borderStyle,
              focusedBorder: borderStyle.copyWith(
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2.0,
                ),
              ),
              // Loại bỏ border mặc định của Dropdown nếu cần
              border: borderStyle,
            ),
            icon: const IconButton(
              mouseCursor: SystemMouseCursors.click,
              onPressed: null,
              icon: Icon(Icons.keyboard_arrow_down_outlined),
            ),
          ),
        ),
      ],
    );
  }
}
