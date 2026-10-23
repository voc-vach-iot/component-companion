import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/widget/storage/led_color_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Đọc số từ ô nhập (chấp nhận dấu phẩy), null nếu không hợp lệ.
double? parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(",", "."));

String formatNumber(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Thêm / sửa loại khay: kích thước, số ngăn, màu LED nhìn rõ qua nhựa.
class TrayTypeDialog extends HookWidget {
  final TrayType? type;

  /// Trả về true nếu lưu thành công (khi đó dialog tự đóng).
  final Future<bool> Function(TrayType type) onSave;

  const TrayTypeDialog({super.key, this.type, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final t = type;
    final name = useTextEditingController(text: t?.name ?? "");
    final width = useTextEditingController(
      text: formatNumber(t?.widthMm ?? 100),
    );
    final depth = useTextEditingController(
      text: formatNumber(t?.depthMm ?? 100),
    );
    final height = useTextEditingController(
      text: formatNumber(t?.heightMm ?? 50),
    );
    final gap = useTextEditingController(
      text: formatNumber(t?.stackGapMm ?? 0),
    );
    final compartments = useTextEditingController(
      text: (t?.compartmentCount ?? 1).toString(),
    );
    final note = useTextEditingController(text: t?.note ?? "");
    final vertical = useState(t?.compartmentVertical ?? false);
    final removable = useState(t?.removableDividers ?? false);
    final fixed = useState(t?.isColorFixed ?? false);
    final allowed = useState<List<int>>(t?.allowedColors ?? const []);
    final defaultColor = useState(t?.defaultColor ?? 0xFF00FF00);
    final compartmentColors = useState<List<int>>(
      t?.compartmentColorList() ?? TrayType.defaultCompartmentColors,
    );
    final brightness = useState(
      RangeValues(
        (t?.minBrightness ?? 40).toDouble(),
        (t?.maxBrightness ?? 255).toDouble(),
      ),
    );
    final saving = useState(false);
    useListenable(name);
    useListenable(compartments);
    final slotCount = int.tryParse(compartments.text.trim()) ?? 1;

    /// Màu báo ngăn thứ [i] (thiếu thì lấy màu mặc định theo vòng đỏ / xanh lá / xanh dương).
    int compartmentColor(int i) => i < compartmentColors.value.length
        ? compartmentColors.value[i]
        : TrayType.defaultCompartmentColors[i %
              TrayType.defaultCompartmentColors.length];
    final canSave =
        name.text.trim().isNotEmpty &&
        (!fixed.value || allowed.value.isNotEmpty);

    Future<void> save() async {
      if (!canSave || saving.value) return;
      final colors = fixed.value ? allowed.value : const <int>[];
      final next = TrayType(
        id: t?.id ?? 0,
        name: name.text.trim(),
        widthMm: parseNumber(width.text) ?? 0,
        depthMm: parseNumber(depth.text) ?? 0,
        heightMm: parseNumber(height.text) ?? 0,
        stackGapMm: parseNumber(gap.text) ?? 0,
        compartmentCount: int.tryParse(compartments.text.trim()) ?? 0,
        compartmentVertical: vertical.value,
        removableDividers: removable.value,
        defaultColor: colors.isEmpty || colors.contains(defaultColor.value)
            ? defaultColor.value
            : colors.first,
        minBrightness: brightness.value.start.round(),
        maxBrightness: brightness.value.end.round(),
        note: note.text.trim(),
      )..allowedColors = colors;
      final perCompartment = [
        for (var i = 0; i < slotCount.clamp(1, 12); i++) compartmentColor(i),
      ];
      final defaults = [
        for (var i = 0; i < perCompartment.length; i++)
          TrayType.defaultCompartmentColors[i %
              TrayType.defaultCompartmentColors.length],
      ];
      // Giữ mặc định thì lưu rỗng: sau này đổi bảng màu mặc định vẫn theo
      next.setCompartmentColors(
        listEquals(perCompartment, defaults) ? const [] : perCompartment,
      );
      saving.value = true;
      final ok = await onSave(next);
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    Widget numberField(String label, TextEditingController c, {String? hint}) =>
        Expanded(
          child: AppTextField(
            label: label,
            controller: c,
            hintText: hint ?? "",
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        );

    const sectionStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: AppColors.textMain,
    );

    return AppAlertDialog(
      title: t == null ? "Thêm loại khay" : "Sửa loại khay",
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: "Tên loại khay",
              controller: name,
              hintText: "VD: Khay A6",
              autofocus: t == null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                numberField("Rộng (mm)", width),
                const SizedBox(width: 8),
                numberField("Sâu (mm)", depth),
                const SizedBox(width: 8),
                numberField("Cao (mm)", height),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                numberField("Thanh kê giữa 2 tầng (mm)", gap),
                const SizedBox(width: 8),
                numberField("Số ngăn", compartments),
              ],
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: removable.value,
              onChanged: (v) => removable.value = v ?? false,
              title: const Text("Vách ngăn tháo được"),
              subtitle: const Text(
                "Từng khay trong kho tự chọn gộp ngăn (VD 3 ngăn → 1 to + 1 nhỏ, hoặc 1 ngăn)",
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: vertical.value,
              onChanged: (v) => vertical.value = v ?? false,
              title: const Text("Các ngăn xếp theo chiều dọc"),
              subtitle: const Text(
                "Bỏ chọn: các ngăn nằm cạnh nhau theo chiều ngang",
              ),
            ),
            const Divider(height: 24),
            const Text("Màu LED", style: sectionStyle),
            const SizedBox(height: 4),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text("Màu nào cũng được"),
                  icon: Icon(Icons.palette_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text("Chỉ một số màu"),
                  icon: Icon(Icons.lock_outline_rounded),
                ),
              ],
              selected: {fixed.value},
              onSelectionChanged: (v) {
                fixed.value = v.first;
                if (fixed.value && allowed.value.isEmpty) {
                  allowed.value = [defaultColor.value];
                }
              },
            ),
            const SizedBox(height: 10),
            if (fixed.value) ...[
              const Text(
                "Màu nhìn rõ qua nhựa (VD khay xanh dương dày chỉ để lọt ánh "
                "xanh dương). Bấm để chọn / bỏ:",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in {...ledPresetColors, ...allowed.value})
                    LedColorDot(
                      color: c,
                      selected: allowed.value.contains(c),
                      onTap: () => allowed.value = allowed.value.contains(c)
                          ? (allowed.value.where((x) => x != c).toList())
                          : [...allowed.value, c],
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              !fixed.value && slotCount > 1
                  ? "Màu mặc định (khi khay gộp lại còn 1 ngăn)"
                  : "Màu mặc định khi tìm linh kiện",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            LedColorPicker(
              value: defaultColor.value,
              allowed: fixed.value ? allowed.value : const [],
              onChanged: (c) => defaultColor.value = c,
            ),
            if (!fixed.value && slotCount > 1) ...[
              const SizedBox(height: 12),
              const Text(
                "Màu báo ngăn (khay đang chia nhiều ngăn: màu cho biết linh kiện "
                "ở ngăn nào, LED sáng liên tục). Đỏ / xanh lá / xanh dương thuần "
                "chỉ bật 1 kênh LED nên ít tốn điện nhất:",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < slotCount.clamp(1, 12); i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 56, child: Text("Ngăn ${i + 1}")),
                      Expanded(
                        child: LedColorPicker(
                          value: compartmentColor(i),
                          onChanged: (c) => compartmentColors.value = [
                            for (var j = 0; j < slotCount.clamp(1, 12); j++)
                              j == i ? c : compartmentColor(j),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              "Độ sáng: thấp nhất ${brightness.value.start.round()} · cao nhất "
              "${brightness.value.end.round()} (0–255)",
              style: sectionStyle,
            ),
            RangeSlider(
              values: brightness.value,
              min: 0,
              max: 255,
              divisions: 51,
              onChanged: (v) => brightness.value = v,
            ),
            const Text(
              "Thấp nhất = mức còn nhìn thấy qua nhựa. Nguồn không đủ để sáng hết "
              "ở mức này thì LED sáng luân phiên theo lượt thay vì sáng mờ.",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            AppTextField(label: "Ghi chú", controller: note, maxLines: 2),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: t == null ? "Thêm mới" : "Lưu thay đổi",
          size: ButtonSize.small,
          isDisabled: !canSave || saving.value,
          onPressed: save,
        ),
      ],
    );
  }
}
