import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/material.dart';

part 'category_color.mapper.dart';

@MappableEnum()
enum CategoryColor {
  // --- MÀU MẶC ĐỊNH (Cốt lõi) ---
  purple("Tím", Color(0xFFE0BBE4), isDefault: true),
  blue("Xanh Dương", Color(0xFFBAE1FF), isDefault: true),
  pink("Hồng", Color(0xFFFFD1DC), isDefault: true),
  mint("Xanh Mint", Color(0xFFB9FBC0), isDefault: true),
  yellow("Vàng", Color(0xFFFFF1BA), isDefault: true),
  orange("Cam", Color(0xFFFFD1BA), isDefault: true),

  // --- MÀU DỰ PHÒNG (Mở rộng) ---
  grey("Xám", Color(0xFFE2E2E2), isDefault: false),
  beige("Be", Color(0xFFF5E6CC), isDefault: false),
  teal("Xanh Teal", Color(0xFFB2F2F2), isDefault: false),
  lavender("Lavender", Color(0xFFC7CEEA), isDefault: false),
  peach("Đào", Color(0xFFFFC8A2), isDefault: false),
  lime("Xanh Chanh", Color(0xFFE8F7A2), isDefault: false),
  sky("Xanh Trời", Color(0xFFD1E8FF), isDefault: false),
  slate("Xám Xanh", Color(0xFFD7DBDD), isDefault: false);

  final String label;
  final Color color;
  final bool isDefault;

  const CategoryColor(this.label, this.color, {this.isDefault = false});

  static CategoryColor? fromString(String? value) {
    try {
      if (value == null) return null;
      return CategoryColorMapper.fromValue(value);
    } catch (_) {
      return null;
    }
  }

  static CategoryColor fromValue(String value) {
    return CategoryColorMapper.fromValue(value);
  }
}
