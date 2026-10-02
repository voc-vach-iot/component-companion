import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/variant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Soạn các thuộc tính biến thể của linh kiện, VD:
///   Màu:       [Đỏ] [Xanh] [Vàng]
///   Chiều dài: [5mm] [8mm] [10mm]
///
/// Tuỳ chọn mua hàng KHÔNG phải nhân lên theo tổ hợp: mặc định mỗi tuỳ chọn
/// áp dụng cho mọi biến thể, chỉ giới hạn khi giá khác nhau.
class VariantAttributesEditor extends HookWidget {
  final List<VariantAttribute> initial;
  final ValueChanged<List<VariantAttribute>> onChanged;

  /// Tên thuộc tính gợi ý (từ loại linh kiện), VD ["Chiều dài", "Kiểu"].
  final List<String> suggestions;

  const VariantAttributesEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.suggestions = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Mỗi dòng có key riêng để giữ state ô nhập khi thêm/xoá dòng
    final rows = useState<List<_Row>>([
      for (final a in initial) _Row(UniqueKey(), a.name, [...a.values]),
    ]);

    void emit() => onChanged([
      for (final r in rows.value)
        if (r.name.trim().isNotEmpty && r.values.isNotEmpty)
          VariantAttribute(r.name.trim(), r.values),
    ]);

    void update(void Function(List<_Row> rows) change) {
      final next = [...rows.value];
      change(next);
      rows.value = next;
      emit();
    }

    final usedNames = rows.value
        .map((r) => r.name.trim().toLowerCase())
        .toSet();
    final unusedSuggestions = suggestions
        .where((s) => !usedNames.contains(s.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Biến thể (thuộc tính)",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => update((r) => r.add(_Row(UniqueKey(), "", []))),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text("Thêm thuộc tính"),
            ),
          ],
        ),
        const Text(
          "VD: Màu (Đỏ, Xanh), Chiều dài (5mm, 8mm). Không cần tạo tuỳ chọn cho "
          "từng tổ hợp: một tuỳ chọn mua hàng mặc định áp dụng cho mọi biến thể.",
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        if (unusedSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                "Gợi ý:",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              for (final name in unusedSuggestions)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 14),
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      update((r) => r.add(_Row(UniqueKey(), name, []))),
                ),
            ],
          ),
        ],
        for (var i = 0; i < rows.value.length; i++)
          Padding(
            key: rows.value[i].key,
            padding: const EdgeInsets.only(top: 10),
            child: _AttributeRow(
              row: rows.value[i],
              onNameChanged: (name) {
                rows.value[i].name = name;
                emit();
              },
              onValuesChanged: (values) =>
                  update((r) => r[i] = _Row(r[i].key, r[i].name, values)),
              onRemove: () => update((r) => r.removeAt(i)),
            ),
          ),
      ],
    );
  }
}

class _Row {
  final Key key;
  String name;
  final List<String> values;

  _Row(this.key, this.name, this.values);
}

class _AttributeRow extends HookWidget {
  final _Row row;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<List<String>> onValuesChanged;
  final VoidCallback onRemove;

  const _AttributeRow({
    required this.row,
    required this.onNameChanged,
    required this.onValuesChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController(text: row.name);
    final valueController = useTextEditingController();
    final valueFocus = useFocusNode();
    final error = useState<String?>(null);

    void addValues(String raw) {
      final next = [...row.values];
      final duplicates = <String>[];
      for (final part in raw.split(",")) {
        final value = part.trim();
        if (value.isEmpty) continue;
        if (next.any((v) => v.toLowerCase() == value.toLowerCase())) {
          duplicates.add(value);
          continue;
        }
        next.add(value);
      }
      error.value = duplicates.isEmpty
          ? null
          : "Đã có: ${duplicates.join(", ")}";
      valueController.clear();
      if (next.length != row.values.length) onValuesChanged(next);
      valueFocus.requestFocus();
    }

    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: AppColors.border),
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: TextField(
              controller: nameController,
              onChanged: onNameChanged,
              decoration: const InputDecoration(
                isDense: true,
                hintText: "Tên (VD: Màu)",
                border: border,
                enabledBorder: border,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: valueController,
                  focusNode: valueFocus,
                  onChanged: (v) {
                    if (v.endsWith(",")) addValues(v);
                  },
                  onSubmitted: addValues,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "Giá trị rồi Enter (VD: Đỏ, Xanh)",
                    border: border,
                    enabledBorder: border,
                    errorText: error.value,
                    suffixIcon: IconButton(
                      tooltip: "Thêm giá trị",
                      icon: const Icon(Icons.add_rounded, size: 18),
                      onPressed: () => addValues(valueController.text),
                    ),
                  ),
                ),
                if (row.values.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final value in row.values)
                        InputChip(
                          label: Text(
                            value,
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.surfaceVariant,
                          side: BorderSide.none,
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                          onDeleted: () => onValuesChanged(
                            row.values.where((v) => v != value).toList(),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: "Xoá thuộc tính",
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.actionDelete,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
