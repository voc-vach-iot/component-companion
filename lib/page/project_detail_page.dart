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
import 'package:component_companion/util/project_duplicates.dart';
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
    // Tab đang mở: 0 = linh kiện chung, khác = id nhóm lựa chọn
    final selectedTab = useState(0);

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
                onAddGroup: () => ProjectGroupAction.showAdd(
                  context,
                  ref,
                  project,
                  onSuccess: (id) => selectedTab.value = id,
                ),
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
                        selectedTab: selectedTab,
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
  /// Dưới độ rộng này tab dọc chuyển thành hàng chip ngang.
  static const double _narrow = 1000;

  final Project project;
  final List<ProjectItem> baseItems;
  final List<ProjectGroup> groups;
  final ValueNotifier<int> selectedTab;

  const _ProjectBody({
    required this.project,
    required this.baseItems,
    required this.groups,
    required this.selectedTab,
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
    // Dòng trùng biến thể trong cùng phần => gợi ý gộp
    final duplicates = ProjectDuplicates.groups([
      ...baseItems,
      for (final g in groups)
        for (final o in g.options) ...o.items,
    ]);

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

    void addGroup() => ProjectGroupAction.showAdd(
      context,
      ref,
      project,
      onSuccess: (id) => selectedTab.value = id,
    );

    final tabs = <_Tab>[
      (
        id: 0,
        icon: Icons.inventory_2_outlined,
        title: "Linh kiện chung",
        subtitle: "${baseItems.length} linh kiện · ${baseTotal.toVND()}",
      ),
      for (final g in groups)
        (
          id: g.id,
          icon: Icons.alt_route_rounded,
          title: g.name,
          subtitle:
              "${g.selectedOption?.name ?? "Chưa chọn"} · ${g.options.length} phương án",
        ),
    ];
    // Nhóm đang mở bị xoá => về linh kiện chung
    final activeId = tabs.any((t) => t.id == selectedTab.value)
        ? selectedTab.value
        : 0;
    final groupIndex = groups.indexWhere((g) => g.id == activeId);

    final Widget selectedSection = groupIndex < 0
        ? ProjectSection(
            icon: Icons.inventory_2_outlined,
            title: "Linh kiện chung",
            subtitle: "Luôn có trong mọi cấu hình",
            total: baseTotal,
            actions: [
              AppButton(
                onPressed: () => BomPasteDialog.show(context, project: project),
                label: "Dán BOM",
                icon: Icons.content_paste_go_rounded,
                variant: ButtonVariant.secondary,
                size: ButtonSize.small,
              ),
              const SizedBox(width: 8),
              AppButton(
                onPressed: () =>
                    ProjectItemAction.showAdd(context, ref, project: project),
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
          )
        : ProjectGroupSection(
            key: ValueKey(groups[groupIndex].id),
            group: groups[groupIndex],
            isFirst: groupIndex == 0,
            isLast: groupIndex == groups.length - 1,
            itemBuilder: itemCard,
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
        if (duplicates.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.copy_all_rounded, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "${duplicates.length} linh kiện bị thêm trùng (cùng biến "
                    "thể, cùng phần): "
                    "${duplicates.map((g) => "${g.first.variant.target?.fullLabel ?? "?"} ×${g.length} dòng ở ${ProjectDuplicates.placeOf(g.first)}").join("; ")}",
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => ProjectItemAction.mergeDuplicates(
                    context,
                    ref,
                    duplicates,
                  ),
                  child: const Text("Xem & gộp"),
                ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < _narrow;
              final content = ListView(
                padding: EdgeInsets.fromLTRB(narrow ? 24 : 16, 16, 24, 32),
                children: [selectedSection],
              );
              if (narrow) {
                return Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        children: [
                          for (final tab in tabs)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: Icon(tab.icon, size: 16),
                                label: Text(tab.title),
                                selected: tab.id == activeId,
                                onSelected: (_) => selectedTab.value = tab.id,
                              ),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: const Text("Thêm nhóm"),
                            onPressed: addGroup,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: content),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 260,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 0, 24),
                      children: [
                        for (final tab in tabs)
                          _SectionTab(
                            tab: tab,
                            selected: tab.id == activeId,
                            onTap: () => selectedTab.value = tab.id,
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: addGroup,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Thêm nhóm lựa chọn"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (groups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              "Nhóm lựa chọn = phần có nhiều phương án, VD "
                              "Vi điều khiển: ESP32 / STM32.",
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

typedef _Tab = ({int id, IconData icon, String title, String subtitle});

/// 1 tab trong cột tab dọc (linh kiện chung / 1 nhóm lựa chọn).
class _SectionTab extends StatelessWidget {
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  const _SectionTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          onTap: onTap,
          leading: Icon(
            tab.icon,
            color: selected ? AppColors.primary : AppColors.textMuted,
          ),
          title: Text(
            tab.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            tab.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}
