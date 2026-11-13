import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/model/unit.dart';
import 'package:component_companion/service/project_stock.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/project/project_stock_dialog.dart';
import 'package:component_companion/widget/project/project_stock_tag.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/storage/locate_action.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectDetailHeader extends StatelessWidget {
  final Project? project;
  final VoidCallback onBack;
  final VoidCallback onAddGroup;
  final VoidCallback onUseCheapest;
  final VoidCallback onShoppingList;
  final VoidCallback onExportBom;

  const ProjectDetailHeader({
    super.key,
    required this.project,
    required this.onBack,
    required this.onAddGroup,
    required this.onUseCheapest,
    required this.onShoppingList,
    required this.onExportBom,
  });

  @override
  Widget build(BuildContext context) {
    final projectName = project?.name ?? "Dự án không tồn tại";

    String projectDescription = project?.description ?? "Không có mô tả.";
    if (projectDescription.isEmpty) {
      projectDescription = "Không có mô tả.";
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            // Tên ít chỗ hơn cụm nút: nút nằm 1 hàng, chỉ xuống dòng khi hẹp
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      projectName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    if (project case final p?)
                      ProjectStockTag(projectId: p.id, status: p.projectStatus),
                  ],
                ),
                Text(
                  projectDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Wrap để các nút xuống dòng khi cửa sổ hẹp
          Flexible(
            flex: 3,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  onPressed: onUseCheapest,
                  label: "Dùng giá rẻ nhất",
                  icon: Icons.savings_outlined,
                  variant: ButtonVariant.secondary,
                ),
                if (project case final p?) _StockMenu(projectId: p.id),
                if (project case final p?) _LocateBomButton(projectId: p.id),
                AppButton(
                  onPressed: onShoppingList,
                  label: "Cần mua",
                  icon: Icons.shopping_cart_outlined,
                  variant: ButtonVariant.secondary,
                ),
                AppButton(
                  onPressed: onExportBom,
                  label: "Xuất BOM",
                  icon: Icons.table_view_outlined,
                  variant: ButtonVariant.secondary,
                ),
                AppButton(
                  onPressed: onAddGroup,
                  label: "Thêm nhóm lựa chọn",
                  icon: Icons.add,
                  variant: ButtonVariant.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sáng LED mọi ngăn chứa linh kiện của cấu hình đang chọn (nhặt hàng).
class _LocateBomButton extends ConsumerWidget {
  final int projectId;

  const _LocateBomButton({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppButton(
      label: "Sáng cả BOM",
      icon: Icons.lightbulb_outline_rounded,
      variant: ButtonVariant.secondary,
      onPressed: () {
        final project = ObjectboxService.instance.get<Project>().get(projectId);
        if (project == null) return;
        final variants = <ComponentVariant>[];
        for (final item in project.configurationItems) {
          final variant =
              item.variant.target ??
              switch (item.component.target?.variants.toList()) {
                [final only] => only,
                _ => null,
              };
          if (variant != null) variants.add(variant);
        }
        if (variants.isEmpty) {
          AppSnackBar.show(
            context,
            message: "Dự án chưa có linh kiện nào chọn biến thể",
            type: SnackBarType.info,
          );
          return;
        }
        locateVariants(context, ref, variants);
      },
    );
  }
}

/// Kho của dự án: trừ phần chưa trừ / trả linh kiện đã lấy về kho. Số liệu
/// đọc lại mỗi lần mở menu (tồn kho đổi ở nơi khác không làm vẽ lại header).
class _StockMenu extends StatelessWidget {
  final int projectId;

  const _StockMenu({required this.projectId});

  Project? _fresh() => ObjectboxService.instance.get<Project>().get(projectId);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: "Linh kiện dự án đã lấy khỏi kho",
      color: AppColors.background,
      onSelected: (action) => action(),
      itemBuilder: (_) {
        final project = _fresh();
        if (project == null) return const [];
        final service = ProjectStockService();
        int sum(List<ProjectStockLine> lines) =>
            lines.fold(0, (s, l) => s + l.quantity);
        final remainingLines = service.remaining(project);
        final consumedLines = service.consumed(project);
        final remaining = sum(remainingLines);
        final consumed = sum(consumedLines);
        // Khác đơn vị thì không cộng được: ghi số dòng linh kiện
        String qty(List<ProjectStockLine> lines, int total) {
          final units = lines.map((l) => l.variant.unit).toSet();
          return units.length <= 1
              ? (units.firstOrNull ?? QuantityUnit.piece).format(total)
              : "${lines.length} mục";
        }

        final remainingText = qty(remainingLines, remaining);
        final consumedText = qty(consumedLines, consumed);
        return [
          PopupMenuItem(
            enabled: false,
            child: Text(
              consumed == 0
                  ? "Chưa lấy linh kiện nào khỏi kho"
                  : "Đã lấy khỏi kho: $consumedText"
                        "${remaining > 0 ? " · còn $remainingText chưa trừ" : " (đủ cấu hình)"}",
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          PopupMenuItem(
            enabled: remaining > 0,
            value: () => ProjectStockDialog.askConsume(
              context,
              project,
              reason: "Lấy linh kiện cho dự án",
              silent: false,
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.outbox_outlined),
              title: Text(
                remaining > 0
                    ? "Trừ kho / đánh dấu đã trừ ($remainingText)"
                    : "Đã trừ kho đủ",
              ),
              subtitle: remaining > 0
                  ? const Text(
                      "Dự án làm trước khi dùng app: chọn \"chỉ đánh dấu\"",
                      style: TextStyle(fontSize: 11),
                    )
                  : null,
            ),
          ),
          PopupMenuItem(
            enabled: consumed > 0,
            value: () => ProjectStockDialog.askGiveBack(
              context,
              project,
              reason: "Tái sử dụng linh kiện của dự án",
              silent: false,
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.move_to_inbox_outlined),
              title: Text("Trả linh kiện về kho ($consumedText)"),
            ),
          ),
        ];
      },
      child: IgnorePointer(
        child: AppButton(
          onPressed: () {},
          label: "Kho",
          icon: Icons.inventory_2_outlined,
          variant: ButtonVariant.secondary,
        ),
      ),
    );
  }
}
