import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/util/led_protocol.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/widget/storage/tray_type_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Thêm / sửa kho: kích thước mặt trước, dải LED, nguồn đang dùng.
class StorageDialog extends HookWidget {
  final Storage? storage;
  final List<PowerSupply> supplies;
  final Future<bool> Function(Storage storage) onSave;

  const StorageDialog({
    super.key,
    this.storage,
    required this.supplies,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final s = storage;
    final name = useTextEditingController(text: s?.name ?? "");
    final width = useTextEditingController(
      text: formatNumber(s?.widthMm ?? 1000),
    );
    final height = useTextEditingController(
      text: formatNumber(s?.heightMm ?? 800),
    );
    final grid = useTextEditingController(text: formatNumber(s?.gridMm ?? 10));
    final ledCount = useTextEditingController(
      text: (s?.ledCount ?? 60).toString(),
    );
    final mAPerChannel = useTextEditingController(
      text: formatNumber(s?.mAPerChannel ?? 20),
    );
    final idle = useTextEditingController(
      text: formatNumber(s?.idleMaPerLed ?? 0.6),
    );
    final mcu = useTextEditingController(text: formatNumber(s?.mcuMa ?? 120));
    final timeout = useTextEditingController(
      text: (s?.lightTimeoutS ?? 60).toString(),
    );
    final note = useTextEditingController(text: s?.note ?? "");
    final colorOrder = useState(s?.colorOrder ?? "GRB");
    final supplyId = useState<int>(
      s?.powerSupply.targetId ?? supplies.firstOrNull?.id ?? 0,
    );
    final saving = useState(false);
    useListenable(name);
    final canSave = name.text.trim().isNotEmpty;

    Future<void> save() async {
      if (!canSave || saving.value) return;
      saving.value = true;
      final next = Storage(
        id: s?.id ?? 0,
        name: name.text.trim(),
        widthMm: parseNumber(width.text) ?? 0,
        heightMm: parseNumber(height.text) ?? 0,
        gridMm: parseNumber(grid.text) ?? 0,
        ledCount: int.tryParse(ledCount.text.trim()) ?? 0,
        colorOrder: colorOrder.value,
        mAPerChannel: parseNumber(mAPerChannel.text) ?? 0,
        idleMaPerLed: parseNumber(idle.text) ?? -1,
        mcuMa: parseNumber(mcu.text) ?? -1,
        lightTimeoutS: int.tryParse(timeout.text.trim()) ?? 0,
        bleDeviceId: s?.bleDeviceId ?? "",
        bleName: s?.bleName ?? "",
        note: note.text.trim(),
      )..powerSupply.targetId = supplyId.value;
      final ok = await onSave(next);
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    Widget field(String label, TextEditingController c) => Expanded(
      child: AppTextField(
        label: label,
        controller: c,
        keyboardType: numberKeyboard,
      ),
    );
    const sectionStyle = TextStyle(fontWeight: FontWeight.w600);

    return AppAlertDialog(
      title: s == null ? "Thêm kho" : "Cài đặt kho",
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: "Tên kho",
              controller: name,
              hintText: "VD: Kệ bàn làm việc",
              autofocus: s == null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                field("Rộng (mm)", width),
                const SizedBox(width: 8),
                field("Cao (mm)", height),
                const SizedBox(width: 8),
                field("Bước lưới (mm)", grid),
              ],
            ),
            const Divider(height: 28),
            const Text("Dải LED", style: sectionStyle),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                field("Số LED", ledCount),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: colorOrder.value,
                    decoration: const InputDecoration(labelText: "Thứ tự màu"),
                    items: [
                      for (final o in LedProtocol.colorOrders)
                        DropdownMenuItem(
                          value: o,
                          child: Text(o == "GRB" ? "GRB (WS2812B)" : o),
                        ),
                    ],
                    onChanged: (v) => colorOrder.value = v ?? "GRB",
                  ),
                ),
                const SizedBox(width: 8),
                field("Tự tắt sau (giây)", timeout),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                field("mA / kênh màu", mAPerChannel),
                const SizedBox(width: 8),
                field("mA / LED khi tắt", idle),
                const SizedBox(width: 8),
                field("mA mạch điều khiển", mcu),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Dùng để giới hạn độ sáng theo nguồn. WS2812B: ~20mA mỗi kênh ở độ "
              "sáng tối đa, ~0.6mA khi tắt. Đo thực tế rồi sửa cho đúng.",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const Divider(height: 28),
            const Text("Nguồn đang dùng", style: sectionStyle),
            const SizedBox(height: 4),
            if (supplies.isEmpty)
              const Text(
                "Chưa có nguồn nào — thêm ở tab Nguồn (tạm tính 1A cho an toàn).",
                style: TextStyle(color: AppColors.warning),
              )
            else
              RadioGroup<int>(
                groupValue: supplyId.value,
                onChanged: (v) => supplyId.value = v ?? 0,
                child: Column(
                  children: [
                    for (final p in supplies)
                      RadioListTile<int>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: p.id,
                        title: Text(p.name),
                        subtitle: Text(
                          "${p.spec} · dùng tối đa ${(p.derate * 100).round()}%",
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
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
