import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';

class AppAutocomplete<T extends Object> extends StatelessWidget {
  final String label;
  final List<T> options;
  final T? initialValue;
  final String Function(T) displayStringForOption;
  final Function(T) onSelected;

  const AppAutocomplete({
    super.key,
    required this.label,
    required this.options,
    this.initialValue,
    required this.displayStringForOption,
    required this.onSelected,
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
        Autocomplete<T>(
          initialValue: initialValue != null
              ? TextEditingValue(text: displayStringForOption(initialValue!))
              : null,
          displayStringForOption: displayStringForOption,
          optionsBuilder: (text) => text.text.isEmpty
              ? options
              : options.where(
                  (o) => displayStringForOption(
                    o,
                  ).toLowerCase().contains(text.text.toLowerCase()),
                ),
          onSelected: onSelected,
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: MediaQuery.of(
                    context,
                  ).size.width, // Rộng bằng cái textfield
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        title: Text(displayStringForOption(option)),
                        mouseCursor: SystemMouseCursors.click,
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
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
                border: borderStyle,
                suffixIcon: const Icon(Icons.search), // Biểu tượng gợi ý
              ),
            );
          },
        ),
      ],
    );
  }
}
