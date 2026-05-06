import 'package:flutter/material.dart';
import 'package:component_companion/constant/app_colors.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? prefixText;
  final int? maxLength;
  final int? maxLines;
  final String hintText;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final bool autofocus;

  const AppTextField({
    super.key,
    required this.label,
    this.hintText = "",
    this.prefixText = "",
    this.controller,
    this.isPassword = false,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    const borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.border, width: 1.0),
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
        TextField(
          controller: controller,
          obscureText: isPassword,
          maxLength: maxLength,
          keyboardType: keyboardType,
          focusNode: focusNode,
          autofocus: autofocus,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textMain),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: AppColors.textDisabled),
            filled: true,
            prefixText: prefixText,
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
          ),
        ),
      ],
    );
  }
}
