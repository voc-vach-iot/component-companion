import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

part 'category_icon.mapper.dart';

@MappableEnum()
enum CategoryIcon {
  cpu(LucideIcons.cpu, "Vi điều khiển"),
  battery(LucideIcons.battery, "Nguồn điện"),
  monitor(LucideIcons.monitor, "Màn hình"),
  chip(LucideIcons.microchip, "Cảm biến"),
  share(LucideIcons.share2, "Kết nối"),
  wifi(LucideIcons.wifi, "Truyền thông"),
  zap(LucideIcons.zap, "Linh kiện thụ động"),
  diod(LucideIcons.zap, "LED/Diode"), // Bổ sung
  thermometer(LucideIcons.thermometer, "Cảm biến nhiệt"), // Bổ sung
  toggle(LucideIcons.toggleLeft, "Công tắc/Nút"), // Bổ sung
  database(LucideIcons.database, "Module lưu trữ"), // Bổ sung
  box(LucideIcons.box, "Khác");

  final IconData icon;
  final String label;

  const CategoryIcon(this.icon, this.label);

  static CategoryIcon? fromString(String? value) {
    try {
      if (value == null) return null;
      return CategoryIconMapper.fromValue(value);
    } catch (_) {
      return null;
    }
  }

  static CategoryIcon fromValue(String value) {
    return CategoryIconMapper.fromValue(value);
  }
}
