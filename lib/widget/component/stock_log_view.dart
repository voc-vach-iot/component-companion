import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/notifier/variant_notifier.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Danh sách nhật ký kho (mới nhất trước).
class StockLogList extends ConsumerWidget {
  /// null = mọi biến thể.
  final int? variantId;

  /// Lọc thêm trong Dart (trang tổng: theo lý do / từ khoá).
  final bool Function(StockLog log)? where;

  const StockLogList({super.key, this.variantId, this.where});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(watchStockLogsProvider(variantId: variantId));
    return logsAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, _) => AppErrorView(message: "Lỗi tải nhật ký kho: $e"),
      data: (all) {
        final logs = where == null ? all : all.where(where!).toList();
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              "Chưa có thay đổi tồn kho nào",
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          itemCount: logs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) =>
              StockLogTile(log: logs[i], showLabel: variantId == null),
        );
      },
    );
  }
}

class StockLogTile extends StatelessWidget {
  final StockLog log;
  final bool showLabel;

  const StockLogTile({super.key, required this.log, this.showLabel = true});

  static String formatTime(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    final isMark = log.stockReason == StockReason.projectMark;
    final delta = isMark ? 0 : log.delta;
    final color = isMark
        ? AppColors.info
        : delta > 0
        ? AppColors.success
        : delta < 0
        ? AppColors.error
        : AppColors.textMuted;
    final reason = log.stockReason;
    final project = log.project.target?.name;
    final detail = [
      reason.label,
      if (project != null && !log.note.contains(project)) project,
      if (log.note.isNotEmpty) log.note,
      formatTime(log.at),
    ].join(" · ");

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(_icon(reason), size: 16, color: color),
      ),
      title: Text(
        showLabel
            ? (log.label.isEmpty ? "(biến thể đã xoá)" : log.label)
            : detail,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: showLabel
          ? Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isMark
                ? "${log.marked > 0 ? "đánh dấu" : "bỏ đánh dấu"} ${log.marked.abs()}"
                : delta > 0
                ? "+$delta"
                : "$delta",
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            isMark
                ? "kho không đổi"
                : "${log.before ?? "—"} → ${log.after ?? "—"}",
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  static IconData _icon(StockReason reason) => switch (reason) {
    StockReason.manual => Icons.edit_outlined,
    StockReason.stockIn => Icons.move_to_inbox_outlined,
    StockReason.import => Icons.file_download_outlined,
    StockReason.received => Icons.local_shipping_outlined,
    StockReason.projectUse => Icons.build_outlined,
    StockReason.projectReturn => Icons.undo_rounded,
    StockReason.projectMark => Icons.bookmark_added_outlined,
    StockReason.merge => Icons.merge_rounded,
    StockReason.undo => Icons.history_rounded,
  };
}

/// Nhật ký kho của 1 biến thể.
class StockLogDialog extends StatelessWidget {
  final int variantId;
  final String title;

  const StockLogDialog({
    super.key,
    required this.variantId,
    required this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required int variantId,
    required String title,
  }) => showDialog(
    context: context,
    builder: (_) => StockLogDialog(variantId: variantId, title: title),
  );

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: "Nhật ký kho · $title",
      cancelLabel: "Đóng",
      content: SizedBox(
        width: 520,
        height: 420,
        child: StockLogList(variantId: variantId),
      ),
    );
  }
}
