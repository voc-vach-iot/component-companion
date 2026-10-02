import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Thêm / sửa 1 biến thể: chọn giá trị từng thuộc tính + tồn kho, vị trí.
class VariantDialog extends HookWidget {
  final Component component;
  final ComponentVariant? variant;

  /// Trả về true nếu lưu thành công (khi đó dialog tự đóng).
  final Future<bool> Function(ComponentVariant variant) onSave;

  const VariantDialog({
    super.key,
    required this.component,
    this.variant,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final attributes = component.attributes;
    final isEdit = variant != null;
    final selection = useState<VariantSelection>(
      variant?.selection ??
          {
            for (final a in attributes)
              if (a.values.length == 1) a.name: a.values.first,
          },
    );
    final stockCtrl = useTextEditingController(
      text: variant?.stock?.toString() ?? "",
    );
    final locationCtrl = useTextEditingController(
      text: variant?.location ?? "",
    );
    final thresholdCtrl = useTextEditingController(
      text: (variant?.lowStockThreshold ?? component.lowStockThreshold)
          .toString(),
    );
    final noteCtrl = useTextEditingController(text: variant?.note ?? "");
    final saving = useState(false);

    final complete = attributes.every((a) => selection.value[a.name] != null);

    Future<void> save() async {
      if (!complete || saving.value) return;
      saving.value = true;
      final stockText = stockCtrl.text.trim();
      final next = ComponentVariant(
        id: variant?.id ?? 0,
        selectionJson: Variants.encodeSelection(selection.value),
        stock: stockText.isEmpty ? null : int.tryParse(stockText),
        location: locationCtrl.text.trim(),
        lowStockThreshold: int.tryParse(thresholdCtrl.text.trim()) ?? 0,
        note: noteCtrl.text.trim(),
      )..component.targetId = component.id;
      final ok = await onSave(next);
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    return AppAlertDialog(
      title: isEdit ? "Sửa biến thể" : "Thêm biến thể",
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in attributes) ...[
                Text(
                  a.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final value in a.values)
                      ChoiceChip(
                        label: Text(value),
                        visualDensity: VisualDensity.compact,
                        selected: selection.value[a.name] == value,
                        onSelected: (_) => selection.value = {
                          ...selection.value,
                          a.name: value,
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (attributes.isNotEmpty)
                const Text(
                  "Thiếu giá trị? Thêm vào thuộc tính ở nút Sửa linh kiện.",
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: "Tồn kho (cái)",
                      controller: stockCtrl,
                      hintText: "Để trống = chưa theo dõi",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: "Cảnh báo khi còn ≤",
                      controller: thresholdCtrl,
                      hintText: "0 = không cảnh báo",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: "Vị trí cất",
                controller: locationCtrl,
                hintText: "VD: Khay A - ô 3",
              ),
              const SizedBox(height: 10),
              AppTextField(label: "Ghi chú", controller: noteCtrl),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: isEdit ? "Lưu thay đổi" : "Thêm mới",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: !complete || saving.value,
          onPressed: save,
        ),
      ],
    );
  }
}

/// Tạo nhiều biến thể cùng lúc: chọn các giá trị của từng thuộc tính, tạo mọi
/// tổ hợp còn thiếu. Chỉ nên tạo những biến thể thực sự có / hay mua.
class VariantBulkDialog extends HookWidget {
  static const maxCombinations = 200;

  final Component component;

  /// Trả về true nếu lưu thành công.
  final Future<bool> Function(List<VariantSelection> selections) onSave;

  const VariantBulkDialog({
    super.key,
    required this.component,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final attributes = component.attributes;
    final existing = useMemoized(
      () => component.variants.map((v) => Variants.key(v.selection)).toSet(),
    );
    final picked = useState<Map<String, Set<String>>>({
      for (final a in attributes) a.name: {},
    });
    final saving = useState(false);

    final chosen = [
      for (final a in attributes)
        VariantAttribute(
          a.name,
          a.values.where(picked.value[a.name]!.contains).toList(),
        ),
    ];
    final ready = chosen.every((a) => a.values.isNotEmpty);
    final combos = ready
        ? Variants.combinations(chosen, max: maxCombinations + 1)
        : const <VariantSelection>[];
    final fresh = combos
        .where((c) => !existing.contains(Variants.key(c)))
        .toList();
    final tooMany = combos.length > maxCombinations;

    void toggle(String name, String value) {
      final next = {...picked.value[name]!};
      next.contains(value) ? next.remove(value) : next.add(value);
      picked.value = {...picked.value, name: next};
    }

    return AppAlertDialog(
      title: "Tạo nhiều biến thể",
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Chọn giá trị của từng thuộc tính, mọi tổ hợp chưa có sẽ được tạo. "
                "Chỉ nên tạo các biến thể bạn đang có hoặc hay mua.",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              for (final a in attributes) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: () => picked.value = {
                        ...picked.value,
                        a.name: picked.value[a.name]!.length == a.values.length
                            ? {}
                            : a.values.toSet(),
                      },
                      child: Text(
                        picked.value[a.name]!.length == a.values.length
                            ? "Bỏ chọn"
                            : "Chọn tất cả",
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final value in a.values)
                      FilterChip(
                        label: Text(value),
                        visualDensity: VisualDensity.compact,
                        selected: picked.value[a.name]!.contains(value),
                        onSelected: (_) => toggle(a.name, value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                !ready
                    ? "Chọn ít nhất 1 giá trị cho mỗi thuộc tính"
                    : tooMany
                    ? "Quá nhiều tổ hợp (> $maxCombinations), hãy chọn ít hơn"
                    : "Sẽ tạo ${fresh.length} biến thể mới"
                          "${combos.length > fresh.length ? " (${combos.length - fresh.length} đã có)" : ""}",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tooMany ? AppColors.error : AppColors.textMain,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: "Tạo",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: fresh.isEmpty || tooMany || saving.value,
          onPressed: () async {
            saving.value = true;
            final ok = await onSave(fresh);
            if (!context.mounted) return;
            saving.value = false;
            if (ok) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
