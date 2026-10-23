import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/service/project_stock.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Hỏi trừ kho khi dự án hoàn thành / cộng lại khi bỏ trạng thái hoàn thành.
class ProjectStockDialog extends HookWidget {
  final Project project;
  final List<ProjectStockLine> lines;

  /// true = trừ kho, false = trả về kho.
  final bool consume;

  /// Lý do mở (hiện ở đầu dialog), VD "Dự án đã hoàn thành".
  final String reason;

  const ProjectStockDialog._({
    required this.project,
    required this.lines,
    required this.consume,
    required this.reason,
  });

  /// Trừ kho phần chưa trừ (VD dự án vừa chuyển sang "Hoàn thành").
  /// Đã trừ đủ => không hỏi. [silent] = không báo khi không có gì để trừ.
  static Future<void> askConsume(
    BuildContext context,
    Project project, {
    String reason = "Dự án đã hoàn thành",
    bool silent = true,
  }) => _ask(context, project, consume: true, reason: reason, silent: silent);

  /// Trả lại kho phần đã trừ để tái sử dụng (VD dự án chuyển sang "Lưu trữ").
  static Future<void> askGiveBack(
    BuildContext context,
    Project project, {
    String reason = "Dự án đã lưu trữ — tháo ra để tái sử dụng linh kiện",
    bool silent = true,
  }) => _ask(context, project, consume: false, reason: reason, silent: silent);

  static Future<void> _ask(
    BuildContext context,
    Project project, {
    required bool consume,
    required String reason,
    required bool silent,
  }) async {
    final service = ProjectStockService();
    final lines = consume
        ? service.remaining(project)
        : service.consumed(project);
    if (lines.isEmpty) {
      if (!silent) {
        AppSnackBar.show(
          context,
          message: consume
              ? "Đã trừ kho đủ cho cấu hình đang chọn"
              : "Dự án chưa lấy linh kiện nào khỏi kho",
          type: SnackBarType.info,
        );
      }
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showDialog<_Choice>(
      context: context,
      builder: (_) => ProjectStockDialog._(
        project: project,
        lines: lines,
        consume: consume,
        reason: reason,
      ),
    );
    if (chosen == null || chosen.lines.isEmpty) return;
    try {
      final logs = switch ((consume, chosen.markOnly)) {
        (true, false) => service.consume(project, chosen.lines),
        (true, true) => service.markConsumed(project, chosen.lines),
        (false, false) => service.giveBack(project, chosen.lines),
        (false, true) => service.unmark(project, chosen.lines),
      };
      AppSnackBar.showWith(
        messenger,
        message: switch ((consume, chosen.markOnly)) {
          (true, false) =>
            "Đã trừ kho ${logs.length} linh kiện cho \"${project.name}\"",
          (true, true) =>
            "Đã đánh dấu ${logs.length} linh kiện đã dùng (tồn kho không đổi)",
          (false, false) => "Đã cộng lại kho ${logs.length} linh kiện",
          (false, true) =>
            "Đã bỏ đánh dấu ${logs.length} linh kiện (tồn kho không đổi)",
        },
        type: SnackBarType.success,
        duration: const Duration(seconds: 10),
        actionLabel: "Hoàn tác",
        onAction: () {
          service.revert(project, logs);
          AppSnackBar.showWith(
            messenger,
            message: "Đã trả lại tồn kho cũ",
            type: SnackBarType.info,
          );
        },
      );
    } catch (e) {
      AppSnackBar.showWith(
        messenger,
        message: "Không cập nhật được tồn kho: $e",
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final checked = useState<Set<int>>({
      for (final l in lines)
        if (!consume || l.tracked) l.variant.id,
    });
    final selected = lines
        .where((l) => checked.value.contains(l.variant.id))
        .toList();
    final untracked = lines.where((l) => !l.tracked).length;
    final short = lines.where((l) => !l.enough).length;

    return AppAlertDialog(
      // Đã có nút "Bỏ qua" (đóng, không đổi kho)
      cancelLabel: null,
      title: consume
          ? "Trừ kho cho dự án \"${project.name}\""
          : "Trả linh kiện về kho từ \"${project.name}\"",
      size: AlertDialogSize.big,
      content: SizedBox(
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              consume
                  ? "$reason: trừ phần linh kiện chưa trừ của cấu hình đang chọn khỏi tồn kho. "
                        "Bỏ chọn dòng không muốn trừ (có thể trừ sau ở trang dự án)."
                  : "$reason: cộng lại vào tồn kho số linh kiện dự án đã lấy. "
                        "Bỏ chọn dòng đã hỏng / không dùng lại được.",
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (consume && short > 0)
              Text(
                "$short dòng không đủ trong kho — tồn kho sẽ về 0.",
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            if (consume && untracked > 0)
              Text(
                "$untracked biến thể không theo dõi tồn kho nên được bỏ qua.",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: lines.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final l = lines[i];
                  final enabled = !consume || l.tracked;
                  final detail = !consume
                      ? "Cộng ${l.quantity} · kho ${l.stock} → ${l.stock + l.quantity}"
                      : !l.tracked
                      ? "Cần ${l.quantity} · không theo dõi tồn kho"
                      : "Cần ${l.quantity} · kho ${l.stock} → ${l.after}"
                            "${l.enough ? "" : " (thiếu ${l.quantity - l.stock})"}";
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: checked.value.contains(l.variant.id),
                    onChanged: enabled
                        ? (v) {
                            final next = {...checked.value};
                            v == true
                                ? next.add(l.variant.id)
                                : next.remove(l.variant.id);
                            checked.value = next;
                          }
                        : null,
                    secondary: ComponentThumbnail.of(l.component, size: 32),
                    title: Text(l.label),
                    subtitle: Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: consume && !l.enough
                            ? AppColors.warning
                            : AppColors.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Bỏ qua",
          size: ButtonSize.small,
          variant: ButtonVariant.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        // Dự án làm trước khi dùng app: kho thực tế đã thiếu sẵn
        Tooltip(
          message: consume
              ? "Linh kiện đã lấy ra từ trước (tồn kho đã đúng): chỉ ghi nhận "
                    "dự án đang giữ, khi tháo dự án sẽ trả lại được"
              : "Chỉ xoá ghi nhận dự án đang giữ, không cộng tồn kho "
                    "(VD đánh dấu nhầm, linh kiện đã hỏng)",
          child: AppButton(
            label: consume ? "Đã trừ tay — chỉ đánh dấu" : "Chỉ bỏ đánh dấu",
            size: ButtonSize.small,
            variant: ButtonVariant.secondary,
            isDisabled: selected.isEmpty,
            onPressed: () =>
                Navigator.pop(context, (lines: selected, markOnly: true)),
          ),
        ),
        AppButton(
          label: consume
              ? "Trừ kho ${selected.length} dòng"
              : "Trả về kho ${selected.length} dòng",
          size: ButtonSize.small,
          variant: ButtonVariant.primary,
          isDisabled: selected.isEmpty,
          onPressed: () =>
              Navigator.pop(context, (lines: selected, markOnly: false)),
        ),
      ],
    );
  }
}

typedef _Choice = ({List<ProjectStockLine> lines, bool markOnly});
