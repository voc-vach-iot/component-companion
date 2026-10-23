import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/widget/storage/tray_type_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Thêm / sửa nguồn cấp cho dải LED.
class PowerSupplyDialog extends HookWidget {
  final PowerSupply? supply;
  final Future<bool> Function(PowerSupply supply) onSave;

  const PowerSupplyDialog({super.key, this.supply, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final s = supply;
    final name = useTextEditingController(text: s?.name ?? "");
    final voltage = useTextEditingController(
      text: formatNumber(s?.voltage ?? 5),
    );
    final current = useTextEditingController(
      text: formatNumber(s?.currentA ?? 2),
    );
    final derate = useTextEditingController(
      text: ((s?.derate ?? 0.8) * 100).round().toString(),
    );
    final note = useTextEditingController(text: s?.note ?? "");
    final saving = useState(false);
    useListenable(name);
    final canSave = name.text.trim().isNotEmpty;

    Future<void> save() async {
      if (!canSave || saving.value) return;
      saving.value = true;
      final ok = await onSave(
        PowerSupply(
          id: s?.id ?? 0,
          name: name.text.trim(),
          voltage: parseNumber(voltage.text) ?? 0,
          currentA: parseNumber(current.text) ?? 0,
          derate: (parseNumber(derate.text) ?? 0) / 100,
          note: note.text.trim(),
        ),
      );
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    return AppAlertDialog(
      title: s == null ? "Thêm nguồn" : "Sửa nguồn",
      size: AlertDialogSize.small,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: "Tên nguồn",
              controller: name,
              hintText: "VD: Adapter 5V 2.4A, Pin Makita + mini360",
              autofocus: s == null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: "Điện áp (V)",
                    controller: voltage,
                    keyboardType: numberKeyboard,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppTextField(
                    label: "Dòng tối đa (A)",
                    controller: current,
                    keyboardType: numberKeyboard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppTextField(
              label: "Chỉ dùng tối đa (% dòng)",
              controller: derate,
              hintText: "80",
              keyboardType: numberKeyboard,
            ),
            const SizedBox(height: 10),
            AppTextField(label: "Ghi chú", controller: note, maxLines: 2),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: s == null ? "Thêm mới" : "Lưu thay đổi",
          size: ButtonSize.small,
          isDisabled: !canSave || saving.value,
          onPressed: save,
        ),
      ],
    );
  }
}
