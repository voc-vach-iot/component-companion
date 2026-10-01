import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Nhập danh sách keyword dạng chip. Enter hoặc dấu phẩy để thêm
/// (có thể dán nhiều keyword cách nhau bởi dấu phẩy).
///
/// Keyword được chuẩn hóa (lowercase, gộp khoảng trắng) và kiểm tra trùng lặp
/// trong danh sách hiện tại + qua [validator] (VD: đã thuộc danh mục khác)
/// trước khi thêm.
class KeywordInput extends HookWidget {
  final String label;
  final List<String> initialKeywords;
  final ValueChanged<List<String>> onChanged;

  /// Trả về thông báo lỗi nếu keyword không được phép thêm, null nếu hợp lệ.
  final String? Function(String keyword)? validator;

  const KeywordInput({
    super.key,
    this.label = "Từ khóa nhận diện",
    required this.initialKeywords,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final keywords = useState<List<String>>(
      KeywordMatcher.normalizeAll(initialKeywords),
    );
    final textController = useTextEditingController();
    final focusNode = useFocusNode();
    final error = useState<String?>(null);

    void addFromText(String raw) {
      final candidates = KeywordMatcher.normalizeAll(raw.split(","));
      if (candidates.isEmpty) return;

      final accepted = [...keywords.value];
      final errors = <String>[];
      for (final keyword in candidates) {
        if (accepted.contains(keyword)) {
          errors.add("'$keyword' đã có trong danh sách");
          continue;
        }
        final message = validator?.call(keyword);
        if (message != null) {
          errors.add(message);
          continue;
        }
        accepted.add(keyword);
      }

      if (accepted.length != keywords.value.length) {
        keywords.value = accepted;
        onChanged(accepted);
      }
      error.value = errors.isEmpty ? null : errors.join("\n");
      textController.clear();
      focusNode.requestFocus();
    }

    void remove(String keyword) {
      final next = keywords.value.where((k) => k != keyword).toList();
      keywords.value = next;
      onChanged(next);
    }

    const borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.border, width: 1.0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label (${keywords.value.length})",
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: textController,
          focusNode: focusNode,
          style: const TextStyle(color: AppColors.textMain),
          onChanged: (value) {
            if (value.endsWith(",")) addFromText(value);
          },
          onSubmitted: addFromText,
          decoration: InputDecoration(
            hintText: "Nhập từ khóa rồi Enter (VD: tụ hóa, electrolytic)",
            hintStyle: const TextStyle(color: AppColors.textDisabled),
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
            errorText: error.value,
            errorMaxLines: 4,
            suffixIcon: IconButton(
              tooltip: "Thêm",
              mouseCursor: SystemMouseCursors.click,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => addFromText(textController.text),
            ),
          ),
        ),
        if (keywords.value.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final keyword in keywords.value)
                InputChip(
                  label: Text(keyword, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.surfaceVariant,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  onDeleted: () => remove(keyword),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
