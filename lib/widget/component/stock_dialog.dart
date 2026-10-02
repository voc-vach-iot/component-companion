import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/stock_repository.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Nhập tồn kho cho 1 linh kiện. Linh kiện có biến thể thì nhập theo từng
/// biến thể (chỉ cần nhập những biến thể đang có, không bắt buộc đủ tổ hợp).
class StockDialog extends HookWidget {
  final Component component;
  final Future<void> Function(List<StockEntry> entries, int lowStockThreshold)
  onSave;

  const StockDialog({super.key, required this.component, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final attributes = component.attributes;
    final hasVariants = attributes.isNotEmpty;

    final rows = useState<List<_StockRow>>(() {
      final existing = [
        for (final s in component.stockItems)
          _StockRow(
            UniqueKey(),
            Variants.sanitizeSelection(s.variant, attributes),
            s.quantity,
            s.location,
          ),
      ];
      if (existing.isEmpty && !hasVariants) {
        return [_StockRow(UniqueKey(), const {}, 0, "")];
      }
      return existing;
    }());
    final thresholdCtrl = useTextEditingController(
      text: component.lowStockThreshold == 0
          ? ""
          : component.lowStockThreshold.toString(),
    );

    final total = rows.value.fold<int>(0, (sum, r) => sum + r.quantity);

    void update(void Function(List<_StockRow> rows) change) {
      final next = [...rows.value];
      change(next);
      rows.value = next;
    }

    /// Tổ hợp biến thể chưa có dòng nào.
    List<VariantSelection> missingCombinations() {
      final used = rows.value.map((r) => Variants.key(r.variant)).toSet();
      return Variants.combinations(
        attributes,
      ).where((c) => !used.contains(Variants.key(c))).toList();
    }

    final combinationCount = hasVariants
        ? Variants.combinations(attributes, max: 1000).length
        : 1;

    return AppAlertDialog(
      title: "Tồn kho: ${component.name}",
      size: AlertDialogSize.big,
      content: SizedBox(
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Tổng: $total cái",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: thresholdCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: "Cảnh báo sắp hết khi ≤",
                      suffixText: "cái",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasVariants
                  ? "Chỉ cần thêm những biến thể bạn đang có."
                  : "Để trống tất cả rồi lưu để bỏ theo dõi tồn kho.",
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: rows.value.isEmpty
                  ? const Center(
                      child: Text(
                        "Chưa theo dõi tồn kho",
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.value.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _StockRowEditor(
                        key: rows.value[i].key,
                        row: rows.value[i],
                        attributes: attributes,
                        onChanged: (row) => update((r) => r[i] = row),
                        onRemove: () => update((r) => r.removeAt(i)),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: hasVariants && missingCombinations().isEmpty
                      ? null
                      : () => update(
                          (r) => r.add(
                            _StockRow(
                              UniqueKey(),
                              hasVariants ? missingCombinations().first : {},
                              0,
                              "",
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(hasVariants ? "Thêm biến thể" : "Thêm dòng"),
                ),
                if (hasVariants && combinationCount <= 60)
                  TextButton.icon(
                    onPressed: missingCombinations().isEmpty
                        ? null
                        : () => update(
                            (r) => r.addAll([
                              for (final c in missingCombinations())
                                _StockRow(UniqueKey(), c, 0, ""),
                            ]),
                          ),
                    icon: const Icon(Icons.grid_on_rounded, size: 18),
                    label: Text("Thêm đủ $combinationCount tổ hợp"),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Lưu tồn kho",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          onPressed: () async {
            // Linh kiện không biến thể: 1 dòng 0 cái & không vị trí = bỏ theo dõi
            final entries = [
              for (final r in rows.value)
                if (hasVariants || r.quantity > 0 || r.location.isNotEmpty)
                  (
                    variant: r.variant,
                    quantity: r.quantity,
                    location: r.location,
                  ),
            ];
            await onSave(entries, int.tryParse(thresholdCtrl.text) ?? 0);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _StockRow {
  final Key key;
  final VariantSelection variant;
  final int quantity;
  final String location;

  _StockRow(this.key, this.variant, this.quantity, this.location);

  _StockRow copyWith({
    VariantSelection? variant,
    int? quantity,
    String? location,
  }) => _StockRow(
    key,
    variant ?? this.variant,
    quantity ?? this.quantity,
    location ?? this.location,
  );
}

class _StockRowEditor extends HookWidget {
  final _StockRow row;
  final List<VariantAttribute> attributes;
  final ValueChanged<_StockRow> onChanged;
  final VoidCallback onRemove;

  const _StockRowEditor({
    super.key,
    required this.row,
    required this.attributes,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final qtyCtrl = useTextEditingController(text: row.quantity.toString());
    final locationCtrl = useTextEditingController(text: row.location);

    void setQuantity(int value) {
      final next = value < 0 ? 0 : value;
      qtyCtrl.text = next.toString();
      onChanged(row.copyWith(quantity: next));
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final a in attributes) ...[
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<String>(
                initialValue: row.variant[a.name],
                isExpanded: true,
                isDense: true,
                decoration: InputDecoration(
                  labelText: a.name,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final v in a.values)
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) => onChanged(
                  row.copyWith(variant: {...row.variant, a.name: v!}),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: "Bớt 1",
            onPressed: () => setQuantity(row.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: qtyCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                labelText: "Số lượng",
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  onChanged(row.copyWith(quantity: int.tryParse(v) ?? 0)),
            ),
          ),
          IconButton(
            tooltip: "Thêm 1",
            onPressed: () => setQuantity(row.quantity + 1),
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                isDense: true,
                labelText: "Vị trí cất (VD: Khay A - ô 3)",
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => onChanged(row.copyWith(location: v)),
            ),
          ),
          IconButton(
            tooltip: "Xoá dòng",
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.actionDelete,
            ),
          ),
        ],
      ),
    );
  }
}
