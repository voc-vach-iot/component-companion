import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/notifier/project_group_notifier.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/project/bom_paste_dialog.dart';
import 'package:component_companion/widget/project/project_group_action.dart';
import 'package:component_companion/widget/project/project_item_action.dart';
import 'package:component_companion/widget/project/project_option_action.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Khung 1 phần của dự án (linh kiện chung / 1 nhóm lựa chọn).
class ProjectSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final double total;
  final List<Widget> actions;

  /// Hiển thị giữa tiêu đề và danh sách (VD chọn phương án).
  final Widget? header;
  final List<Widget> children;

  const ProjectSection({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.total,
    this.actions = const [],
    this.header,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null)
                        TextSpan(
                          text: "   $subtitle",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Text(
                total.toVND(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              ...actions,
            ],
          ),
          if (header != null) ...[const SizedBox(height: 12), header!],
          const SizedBox(height: 12),
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            child,
          ],
        ],
      ),
    );
  }
}

class ProjectEmptyHint extends StatelessWidget {
  final String text;
  const ProjectEmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
    ),
  );
}

/// 1 nhóm lựa chọn: chọn phương án bằng chip (kèm giá từng phương án), bên
/// dưới là linh kiện của phương án đang chọn.
class ProjectGroupSection extends ConsumerWidget {
  final ProjectGroup group;
  final bool isFirst;
  final bool isLast;
  final Widget Function(ProjectItem item) itemBuilder;

  const ProjectGroupSection({
    super.key,
    required this.group,
    required this.isFirst,
    required this.isLast,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = group.sortedOptions;
    final selected = group.selectedOption;
    final items = selected?.items.toList() ?? const <ProjectItem>[];
    final selectedPrice = selected?.totalPrice ?? 0;

    IconButton iconButton(
      IconData icon,
      String tooltip,
      VoidCallback? onPressed, {
      Color? color,
    }) => IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );

    return ProjectSection(
      icon: Icons.alt_route_rounded,
      title: group.name,
      subtitle: "Chọn 1 trong ${options.length} phương án",
      total: selectedPrice,
      actions: [
        iconButton(
          Icons.arrow_upward_rounded,
          "Đưa lên",
          isFirst
              ? null
              : () => ProjectGroupAction.move(context, ref, group, -1),
        ),
        iconButton(
          Icons.arrow_downward_rounded,
          "Đưa xuống",
          isLast ? null : () => ProjectGroupAction.move(context, ref, group, 1),
        ),
        iconButton(
          Icons.edit_outlined,
          "Đổi tên nhóm",
          () => ProjectGroupAction.showEdit(context, ref, group),
        ),
        iconButton(
          Icons.delete_outline,
          "Xoá nhóm",
          () => ProjectGroupAction.showDelete(context, ref, group),
          color: AppColors.error,
        ),
      ],
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final o in options)
                ChoiceChip(
                  selected: o.id == selected?.id,
                  onSelected: (_) =>
                      ProjectOptionAction.select(context, ref, o),
                  label: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: o.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text:
                              "  ${_priceLabel(o.totalPrice, selectedPrice, o.id == selected?.id)}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text("Phương án"),
                onPressed: () => ProjectOptionAction.showAdd(
                  context,
                  ref,
                  group,
                  // Thêm xong chuyển sang dùng phương án mới để thêm linh kiện
                  onSuccess: (id) =>
                      ref.read(projectGroupProvider.notifier).select(id),
                ),
              ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selected.description.isEmpty
                        ? "Đang dùng: ${selected.name}"
                        : "Đang dùng: ${selected.name} — ${selected.description}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Wrap để các nút xuống dòng khi cửa sổ hẹp
                Flexible(
                  flex: 2,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => BomPasteDialog.show(
                          context,
                          projectOption: selected,
                        ),
                        icon: const Icon(
                          Icons.content_paste_go_rounded,
                          size: 16,
                        ),
                        label: const Text("Dán BOM"),
                      ),
                      TextButton.icon(
                        onPressed: () => ProjectOptionAction.duplicate(
                          context,
                          ref,
                          selected,
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text("Nhân bản"),
                      ),
                      TextButton.icon(
                        onPressed: () => ProjectOptionAction.showEdit(
                          context,
                          ref,
                          group,
                          selected,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text("Sửa"),
                      ),
                      TextButton.icon(
                        onPressed: () => ProjectOptionAction.showDelete(
                          context,
                          ref,
                          selected,
                        ),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          "Xoá",
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                      AppButton(
                        onPressed: () => ProjectItemAction.showAdd(
                          context,
                          ref,
                          projectOption: selected,
                        ),
                        label: "Thêm linh kiện",
                        icon: Icons.add,
                        variant: ButtonVariant.primary,
                        size: ButtonSize.small,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      children: [
        if (selected != null && items.isEmpty)
          ProjectEmptyHint(
            "Phương án \"${selected.name}\" chưa có linh kiện. Bấm \"Thêm linh "
            "kiện\" hoặc nhân bản từ phương án khác rồi sửa.",
          ),
        for (final item in items) itemBuilder(item),
      ],
    );
  }

  /// Giá phương án; phương án khác ghi chênh lệch so với phương án đang chọn.
  static String _priceLabel(
    double price,
    double selectedPrice,
    bool isSelected,
  ) {
    if (isSelected) return price.toVND();
    final diff = price - selectedPrice;
    if (diff.abs() < 0.5) return "bằng giá";
    return "${diff > 0 ? "+" : "−"}${diff.abs().toVND()}";
  }
}
