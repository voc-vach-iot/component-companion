import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

part 'category_icon.mapper.dart';

@MappableEnum()
enum CategoryIcon {
  // --- ICON MẶC ĐỊNH ---
  cpu(LucideIcons.cpu, "Vi điều khiển", isDefault: true),
  battery(LucideIcons.battery, "Nguồn điện", isDefault: true),
  monitor(LucideIcons.monitor, "Hiển thị", isDefault: true),
  chip(LucideIcons.microchip, "IC/Chip", isDefault: true),
  wifi(LucideIcons.wifi, "Kết nối", isDefault: true),
  box(LucideIcons.box, "Khác", isDefault: true),

  // --- ICON DỰ PHÒNG ---
  share(LucideIcons.share2, "Giao tiếp", isDefault: false),
  zap(LucideIcons.zap, "Linh kiện thụ động", isDefault: false),
  thermometer(LucideIcons.thermometer, "Cảm biến", isDefault: false),
  toggle(LucideIcons.toggleLeft, "Switch", isDefault: false),
  database(LucideIcons.database, "Lưu trữ", isDefault: false),
  bluetooth(LucideIcons.bluetooth, "Bluetooth", isDefault: false),
  server(LucideIcons.server, "Mainboard", isDefault: false),
  speaker(LucideIcons.speaker, "Âm thanh", isDefault: false);

  final IconData icon;
  final String label;
  final bool isDefault;

  const CategoryIcon(this.icon, this.label, {this.isDefault = false});

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
