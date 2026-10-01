import 'package:flutter/material.dart';

extension ColorExtension on Color {
  /// Màu đậm cùng tông, dùng để vẽ icon/chữ nổi trên nền pastel.
  Color get onPastel {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness(0.32)
        .withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0))
        .toColor();
  }
}
