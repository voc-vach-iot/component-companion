import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

part 'project_status.mapper.dart';

@MappableEnum()
enum ProjectStatus {
  planning(
    LucideIcons.lightbulb,
    Color(0xFFFFF1BA),
    Color(0xFFB45309),
    "Lập kế hoạch",
  ),
  inProgress(
    LucideIcons.loader,
    Color(0xFFBAE1FF),
    Color(0xFF1D4ED8),
    "Đang thực hiện",
  ),
  completed(
    LucideIcons.check,
    Color(0xFFB9FBC0),
    Color(0xFF15803D),
    "Hoàn thành",
  ),
  archived(
    LucideIcons.archive,
    Color(0xFFE2E2E2),
    Color(0xFF4B5563),
    "Lưu trữ",
  );

  final IconData icon;

  /// Màu nền nhạt (pastel) cho thẻ / nhãn.
  final Color color;

  /// Màu đậm cho icon / chữ, đọc rõ trên nền sáng và trên [color].
  final Color foreground;
  final String label;

  const ProjectStatus(this.icon, this.color, this.foreground, this.label);

  static ProjectStatus? fromString(String? value) {
    try {
      if (value == null) return null;
      return ProjectStatusMapper.fromValue(value);
    } catch (_) {
      return null;
    }
  }

  static ProjectStatus fromValue(String value) {
    return ProjectStatusMapper.fromValue(value);
  }
}
