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

  /// true = trừ kho, false = cộng lại.
  final bool consume;

  const ProjectStockDialog._({
    required this.project,
    required this.lines,
    required this.consume,
  });

  /// Dự án vừa chuyển sang "Hoàn thành" => hỏi trừ kho.
  static Future<void> askConsume(BuildContext context, Project project) =>
      _ask(context, project, consume: true);

  /// Dự án rời "Hoàn thành" => hỏi cộng lại phần đã trừ (nếu có).
  static Future<void> askGiveBack(BuildContext context, Project project) =>
      _ask(context, project, consume: false);

  static Future<void> _ask(
    BuildContext context,
    Project project, {
    required bool consume,
  }) async {
    final service = ProjectStockService();
    final lines = consume ? service.usage(project) : service.consumed(project);
    if (lines.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showDialog<List<ProjectStockLine>>(
      context: context,
      builder: (_) => ProjectStockDialog._(
        project: project,
        lines: lines,
        consume: consume,
      ),
    );
    if (chosen == null || chosen.isEmpty) return;
    try {
      final logs = consume
          ? service.consume(project, chosen)
          : service.giveBack(project, chosen);
      AppSnackBar.showWith(
        messenger,
        message: consume
            ? "Đã trừ kho ${logs.length} linh kiện cho \"${project.name}\""
            : "Đã cộng lại kho ${logs.length} linh kiện",
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
      title: consume
          ? "Trừ kho cho dự án \"${project.name}\""
          : "Cộng lại kho từ dự án \"${project.name}\"",
      size: AlertDialogSize.big,
      content: SizedBox(
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              consume
                  ? "Dự án đã hoàn thành: trừ số linh kiện của cấu hình đang chọn khỏi tồn kho. "
                        "Bỏ chọn dòng không muốn trừ."
                  : "Dự án không còn \"Hoàn thành\": cộng lại số đã trừ trước đó vào tồn kho?",
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
        AppButton(
          label: consume
              ? "Trừ kho ${selected.length} dòng"
              : "Cộng lại ${selected.length} dòng",
          size: ButtonSize.small,
          variant: ButtonVariant.primary,
          isDisabled: selected.isEmpty,
          onPressed: () => Navigator.pop(context, selected),
        ),
      ],
    );
  }
}
