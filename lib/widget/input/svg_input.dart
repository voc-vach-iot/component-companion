import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ô nhập (dán) mã SVG kèm preview trực tiếp.
class SvgInputField extends HookWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;

  /// Màu `currentColor` khi preview.
  final Color previewColor;
  final Color? previewBackground;
  final bool tint;

  const SvgInputField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText = '<svg xmlns="http://www.w3.org/2000/svg" ...>...</svg>',
    this.previewColor = AppColors.textMain,
    this.previewBackground,
    this.tint = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = useValueListenable(controller).text.trim();
    final isEmpty = value.isEmpty;
    final isValid = AppSvgIcon.looksLikeSvg(value);

    Future<void> pasteFromClipboard() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) controller.text = text;
    }

    const borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.border, width: 1.0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: pasteFromClipboard,
              icon: const Icon(Icons.content_paste_rounded, size: 16),
              label: const Text("Dán"),
            ),
            if (!isEmpty)
              TextButton.icon(
                onPressed: controller.clear,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text("Xóa"),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 4,
                maxLines: 4,
                style: const TextStyle(
                  fontFamily: "monospace",
                  fontSize: 11,
                  color: AppColors.textMain,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 11,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: borderStyle,
                  focusedBorder: borderStyle.copyWith(
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2.0,
                    ),
                  ),
                  errorText: !isEmpty && !isValid
                      ? "Không phải mã SVG hợp lệ (cần có <svg>...</svg>)"
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // --- PREVIEW ---
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: previewBackground ?? AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: isEmpty
                  ? const Text(
                      "Preview",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    )
                  : !isValid
                  ? const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.error,
                    )
                  : SvgPicture.string(
                      value,
                      width: 56,
                      height: 56,
                      theme: SvgTheme(currentColor: previewColor),
                      colorFilter: tint
                          ? ColorFilter.mode(previewColor, BlendMode.srcIn)
                          : null,
                      errorBuilder: (context, error, stackTrace) =>
                          const Tooltip(
                            message: "SVG lỗi, không thể hiển thị",
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.error,
                            ),
                          ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
