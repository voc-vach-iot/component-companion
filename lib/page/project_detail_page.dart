import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/async/async_value.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/search_params/project_item_search_params.dart';
import 'package:component_companion/notifier/project_group_notifier.dart';
import 'package:component_companion/notifier/project_item_notifier.dart';
import 'package:component_companion/notifier/project_notifier.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/project/bom_paste_dialog.dart';
import 'package:component_companion/widget/project/project_action.dart';
import 'package:component_companion/widget/project/project_detail_header.dart';
import 'package:component_companion/widget/project/project_group_action.dart';
import 'package:component_companion/widget/project/project_group_section.dart';
import 'package:component_companion/widget/project/project_item_action.dart';
import 'package:component_companion/widget/project/project_item_card.dart';
import 'package:component_companion/service/stock_reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Chi tiết dự án: linh kiện chung + các nhóm lựa chọn. Cấu hình đang dùng =
/// linh kiện chung + phương án đang chọn của từng nhóm.
class ProjectDetailPage extends HookConsumerWidget {
  final int projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseItemsSearchParams = useMemoized(
      () => ProjectItemSearchParams(projectId: projectId),
      [projectId],
    );
    final projectAsync = ref.watch(watchProjectByIdProvider(projectId));

    return Container(
      color: AppColors.background,
      child: projectAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, s) =>
            Text("Lỗi: $e", style: const TextStyle(color: AppColors.error)),
        data: (project) {
          if (project == null) {
            return const Center(
              child: Text(
                "Dự án không tồn tại",
                style: TextStyle(color: AppColors.error),
              ),
            );
          }
          final baseItemsAsync = ref.watch(
            watchAllProjectItemsProvider(baseItemsSearchParams),
          );
          final groupsAsync = ref.watch(watchProjectGroupsProvider(projectId));

          return Column(
            children: [
              ProjectDetailHeader(
                project: project,
                onBack: () => Navigator.of(context).pop(),
                onAddGroup: () =>
                    ProjectGroupAction.showAdd(context, ref, project),
                onUseCheapest: () =>
                    ProjectAction.useCheapest(context, ref, project),
                onShoppingList: () =>
                    context.go("/shopping?project=${project.id}"),
                onExportBom: () => ProjectAction.exportBom(context, project),
              ),
              Expanded(
                child: AsyncValueCombine.combine2(baseItemsAsync, groupsAsync)
                    .when(
                      loading: () => const AppLoadingView(),
                      error: (e, s) =>
                          AppErrorView(message: "Lỗi tải dữ liệu dự án: $e"),
                      data: (data) => _ProjectBody(
                        project: project,
                        baseItems: data.$1,
                        groups: data.$2,
                      ),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectBody extends ConsumerWidget {
  final Project project;
  final List<ProjectItem> baseItems;
  final List<ProjectGroup> groups;

  const _ProjectBody({
    required this.project,
    required this.baseItems,
    required this.groups,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double sum(Iterable<ProjectItem> items) =>
        items.fold(0.0, (s, i) => s + i.totalPrice);
    final baseTotal = sum(baseItems);
    final selectedItems = [for (final g in groups) ...g.selectedItems];
    final total = baseTotal + sum(selectedItems);
    var range = (min: baseTotal, max: baseTotal);
    for (final g in groups) {
      final prices = [for (final o in g.options) o.totalPrice];
      if (prices.isEmpty) continue;
      range = (
        min: range.min + prices.reduce((a, b) => a < b ? a : b),
        max: range.max + prices.reduce((a, b) => a > b ? a : b),
      );
    }

    final reservations =
        ref.watch(watchStockReservationsProvider).value ??
        StockReservations.empty;

    Widget itemCard(ProjectItem item) => ProjectItemCard(
      item: item,
      onSwitchOption: (option) =>
          ProjectItemAction.switchOption(context, ref, item, option),
      onQuantityChanged: (q) =>
          ProjectItemAction.setQuantity(context, ref, item, q),
      reservedElsewhere: reservations.holds(
        item.variant.targetId,
        except: {project.id},
      ),
      onEdit: () => ProjectItemAction.showEdit(context, ref, item: item),
      onDelete: () => ProjectItemAction.showDelete(context, ref, item),
    );

    return Column(
      children: [
        // --- TỔNG CẤU HÌNH ĐANG DÙNG ---
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Cấu hình đang dùng",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      groups.isEmpty
                          ? "Linh kiện chung"
                          : [
                              "Linh kiện chung",
                              for (final g in groups)
                                "${g.name}: ${g.selectedOption?.name ?? "—"}",
                            ].join("  ·  "),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    total.toVND(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  if (range.max - range.min >= 1)
                    Text(
                      "Các cấu hình: ${range.min.toVND()} – ${range.max.toVND()}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  Text(
                    "${baseItems.length + selectedItems.length} linh kiện",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              // --- LINH KIỆN CHUNG ---
              ProjectSection(
                icon: Icons.inventory_2_outlined,
                title: "Linh kiện chung",
                subtitle: "Luôn có trong mọi cấu hình",
                total: baseTotal,
                actions: [
                  AppButton(
                    onPressed: () =>
                        BomPasteDialog.show(context, project: project),
                    label: "Dán BOM",
                    icon: Icons.content_paste_go_rounded,
                    variant: ButtonVariant.secondary,
                    size: ButtonSize.small,
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    onPressed: () => ProjectItemAction.showAdd(
                      context,
                      ref,
                      project: project,
                    ),
                    label: "Thêm linh kiện",
                    icon: Icons.add,
                    variant: ButtonVariant.primary,
                    size: ButtonSize.small,
                  ),
                ],
                children: [
                  if (baseItems.isEmpty)
                    const ProjectEmptyHint(
                      "Chưa có linh kiện chung. Linh kiện dùng chung cho mọi "
                      "cấu hình (dây, nút nhấn, vỏ hộp...) thêm ở đây.",
                    ),
                  for (final item in baseItems) itemCard(item),
                ],
              ),

              // --- NHÓM LỰA CHỌN ---
              for (final (index, group) in groups.indexed)
                ProjectGroupSection(
                  key: ValueKey(group.id),
                  group: group,
                  isFirst: index == 0,
                  isLast: index == groups.length - 1,
                  itemBuilder: itemCard,
                ),

              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    ProjectGroupAction.showAdd(context, ref, project),
                icon: const Icon(Icons.add),
                label: Text(
                  groups.isEmpty
                      ? "Thêm nhóm lựa chọn (VD: Vi điều khiển: ESP32 / STM32)"
                      : "Thêm nhóm lựa chọn",
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
