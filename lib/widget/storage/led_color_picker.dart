import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// Màu LED hay dùng, xếp theo số kênh WS2812 phải bật (ít kênh = ít tốn điện):
/// 3 màu thuần 1 kênh, rồi 2 kênh, cuối cùng trắng 3 kênh.
const ledPresetColors = [
  0xFFFF0000, // đỏ
  0xFF00FF00, // xanh lá
  0xFF0000FF, // xanh dương
  0xFFFFFF00, // vàng (đỏ + xanh lá)
  0xFFFF00FF, // tím (đỏ + xanh dương)
  0xFF00FFFF, // xanh ngọc (xanh lá + xanh dương)
  0xFFFF8000, // cam
  0xFFFFFFFF, // trắng
];

/// Ô tròn hiển thị màu LED (có viền để thấy cả màu trắng).
class LedColorDot extends StatelessWidget {
  final int color;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  const LedColorDot({
    super.key,
    required this.color,
    this.size = 22,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(color),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.textMain : AppColors.borderStrong,
          width: selected ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Color(color).withValues(alpha: 0.5), blurRadius: 4),
        ],
      ),
    );
    if (onTap == null) return dot;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: dot,
    );
  }
}

/// Chọn 1 màu LED: các màu có sẵn + tuỳ chỉnh.
class LedColorPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  /// Chỉ cho chọn trong các màu này (rỗng = mọi màu).
  final List<int> allowed;

  const LedColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowed = const [],
  });

  static Future<int?> pickCustom(BuildContext context, int initial) {
    var picked = Color(initial);
    return showDialog<int>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: "Chọn màu LED",
        content: ColorPicker(
          pickerColor: picked,
          enableAlpha: false,
          labelTypes: const [],
          onColorChanged: (c) => picked = c,
        ),
        actions: [
          AppButton(
            label: "Chọn",
            size: ButtonSize.small,
            onPressed: () => Navigator.pop(ctx, picked.toARGB32()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = allowed.isNotEmpty
        ? allowed
        : [...ledPresetColors, if (!ledPresetColors.contains(value)) value];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in colors)
          LedColorDot(
            color: c,
            selected: c == value,
            onTap: () => onChanged(c),
          ),
        if (allowed.isEmpty)
          IconButton(
            tooltip: "Màu khác",
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.colorize_rounded, size: 18),
            onPressed: () async {
              final c = await pickCustom(context, value);
              if (c != null) onChanged(c);
            },
          ),
      ],
    );
  }
}
