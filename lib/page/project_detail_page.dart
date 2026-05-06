import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/async/async_value.dart';
import 'package:component_companion/model/search_params/project_item_search_params.dart';
import 'package:component_companion/model/search_params/project_option_search_params.dart';
import 'package:component_companion/notifier/project_item_notifier.dart';
import 'package:component_companion/notifier/project_notifier.dart';
import 'package:component_companion/notifier/project_option_notifier.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/project/project_detail_header.dart';
import 'package:component_companion/widget/project/project_item_action.dart';
import 'package:component_companion/widget/project/project_item_card.dart';
import 'package:component_companion/widget/project/project_option_action.dart';
import 'package:component_companion/widget/project/project_option_tab_content.dart';
import 'package:component_companion/widget/view/list_view.dart';
import 'package:component_companion/widget/view/tab/tab_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectDetailPage extends HookConsumerWidget {
  final int projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tối ưu hóa param để tránh recreat khi rebuild
    final baseItemsSearchParams = useMemoized(
      () => ProjectItemSearchParams(projectId: projectId),
      [projectId],
    );
    final projectOptionsSearchParams = useMemoized(
      () => ProjectOptionSearchParams(projectId: projectId),
      [projectId],
    );

    return Container(
      color: AppColors.background,
      child: Consumer(
        builder: (context, ref, _) {
          final projectAsync = ref.watch(watchProjectByIdProvider(projectId));
          return projectAsync.when(
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
              return Column(
                children: [
                  ProjectDetailHeader(
                    project: project,
                    onBack: () => Navigator.of(context).pop(),
                    onAddOption: () {
                      ProjectOptionAction.showAdd(context, ref, project);
                    },
                  ),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final baseItemsAsync = ref.watch(
                          watchAllProjectItemsProvider(baseItemsSearchParams),
                        );
                        final projectOptionsAsync = ref.watch(
                          watchAllProjectOptionsProvider(
                            projectOptionsSearchParams,
                          ),
                        );

                        return AsyncValueCombine.combine2(
                          baseItemsAsync,
                          projectOptionsAsync,
                        ).when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, s) =>
                              Center(child: Text("Lỗi tải dữ liệu: $e")),
                          data: (data) {
                            final baseItems = data.$1;
                            final projectOptions = data.$2;

                            // Định nghĩa cấu trúc tab
                            final tabLabels = [
                              "Linh kiện cơ bản",
                              ...projectOptions.map((o) => o.name),
                            ];

                            return HookBuilder(
                              key: ValueKey(tabLabels.length),
                              builder: (context) {
                                final tabController = useTabController(
                                  initialLength: tabLabels.length,
                                );

                                return Column(
                                  children: [
                                    Container(
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                      ),
                                      child: TabBar(
                                        controller: tabController,
                                        isScrollable: true,
                                        tabAlignment: TabAlignment.start,
                                        labelColor: AppColors.textMain,
                                        unselectedLabelColor:
                                            AppColors.textMuted,
                                        indicatorColor: AppColors.primary,
                                        tabs: tabLabels
                                            .map((l) => Tab(text: l))
                                            .toList(),
                                      ),
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        controller: tabController,
                                        children: [
                                          // Tab 1: Linh kiện cơ bản
                                          AppTabContent(
                                            title: "Linh kiện cơ bản",
                                            headerAction: AppButton(
                                              onPressed: () {
                                                ProjectItemAction.showAdd(
                                                  context,
                                                  ref,
                                                  project: project,
                                                );
                                              },
                                              label: "Thêm linh kiện",
                                              icon: Icons.add,
                                              variant: ButtonVariant.primary,
                                            ),
                                            child: GenericList(
                                              items: baseItems,
                                              itemBuilder: (ctx, item) =>
                                                  ProjectItemCard(
                                                    item: item,
                                                    onEdit: () {
                                                      ProjectItemAction.showEdit(
                                                        context,
                                                        ref,
                                                        item: item,
                                                      );
                                                    },
                                                    onDelete: () {
                                                      ProjectItemAction.showDelete(
                                                        context,
                                                        ref,
                                                        item,
                                                      );
                                                    },
                                                  ),
                                            ),
                                          ),
                                          // Tab n: Các Options
                                          ...projectOptions.map(
                                            (opt) => ProjectOptionTabContent(
                                              option: opt,
                                              onAddItem: () {
                                                ProjectItemAction.showAdd(
                                                  context,
                                                  ref,
                                                  projectOption: opt,
                                                );
                                              },
                                              onEdit: () {
                                                ProjectOptionAction.showEdit(
                                                  context,
                                                  ref,
                                                  opt,
                                                );
                                              },
                                              onDelete: () {
                                                ProjectOptionAction.showDelete(
                                                  context,
                                                  ref,
                                                  opt,
                                                );
                                              },
                                              itemBuilder: (item) =>
                                                  ProjectItemCard(
                                                    item: item,
                                                    onEdit: () {
                                                      ProjectItemAction.showEdit(
                                                        context,
                                                        ref,
                                                        item: item,
                                                      );
                                                    },
                                                    onDelete: () {
                                                      ProjectItemAction.showDelete(
                                                        context,
                                                        ref,
                                                        item,
                                                      );
                                                    },
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
