import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

part 'project_status.mapper.dart';

@MappableEnum()
enum ProjectStatus {
  planning(LucideIcons.lightbulb, Color(0xFFFFF1BA), "Lập kế hoạch"),
  inProgress(LucideIcons.loader, Color(0xFFBAE1FF), "Đang thực hiện"),
  completed(LucideIcons.check, Color(0xFFB9FBC0), "Hoàn thành"),
  archived(LucideIcons.archive, Color(0xFFE2E2E2), "Lưu trữ");

  final IconData icon;
  final Color color;
  final String label;

  const ProjectStatus(this.icon, this.color, this.label);

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
