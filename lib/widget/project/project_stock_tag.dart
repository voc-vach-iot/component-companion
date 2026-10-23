import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/notifier/project_notifier.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Nhãn tình trạng kho của dự án: đã trừ / trừ một phần / chưa trừ.
/// Dự án chưa hoàn thành mà chưa lấy gì thì không hiện.
class ProjectStockTag extends ConsumerWidget {
  final int projectId;
  final ProjectStatus status;

  const ProjectStockTag({
    super.key,
    required this.projectId,
    required this.status,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(watchProjectStockStatusProvider(projectId)).value;
    if (s == null || s.needed == 0) return const SizedBox.shrink();
    final done = status == ProjectStatus.completed;
    final (label, color, tooltip) = switch (s) {
      _ when s.consumed >= s.needed => (
        "Đã trừ kho",
        AppColors.success,
        "Đã lấy đủ ${s.needed} linh kiện khỏi kho cho dự án",
      ),
      _ when s.consumed > 0 => (
        "Trừ một phần ${s.consumed}/${s.needed}",
        AppColors.warning,
        "Mới lấy ${s.consumed}/${s.needed} linh kiện khỏi kho",
      ),
      _ when done => (
        "Chưa trừ kho",
        AppColors.textMuted,
        "Dự án đã hoàn thành nhưng chưa trừ / đánh dấu linh kiện "
            "(nút Kho ở trang dự án)",
      ),
      _ => (null, null, null),
    };
    if (label == null) return const SizedBox.shrink();
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color!.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
