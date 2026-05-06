import 'package:component_companion/extension/async/async_value.dart';
import 'package:component_companion/model/search_params/project_item_search_params.dart';
import 'package:component_companion/model/search_params/project_option_search_params.dart';
import 'package:component_companion/model/search_params/project_search_params.dart'; // Giả sử bạn có class này
import 'package:component_companion/notifier/project_item_notifier.dart';
import 'package:component_companion/notifier/project_notifier.dart';
import 'package:component_companion/notifier/project_option_notifier.dart';
import 'package:component_companion/widget/view/grid_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/pagination.dart';
import 'package:component_companion/widget/project/project_action.dart';
import 'package:component_companion/widget/project/project_card.dart';
import 'package:component_companion/widget/project/project_option_price_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectPage extends HookConsumerWidget {
  const ProjectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchParamsProvider = useState(ProjectSearchParams());

    // Watch danh sách dự án dựa trên searchParams
    final pageResultAsync = ref.watch(
      watchProjectsProvider(searchParamsProvider.value),
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header: Tiêu đề + Tìm kiếm + Nút Thêm dự án
          AppHeader(
            title: "Quản lý dự án".toUpperCase(),
            onSearch: (value) {
              searchParamsProvider.value = searchParamsProvider.value.copyWith(
                name: value,
              );
            },
            onAddPressed: () => ProjectAction.showAdd(context, ref),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: pageResultAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text("Lỗi: $e")),
              data: (pageResult) {
                return Column(
                  children: [
                    Expanded(
                      child: GenericGrid(
                        maxWidth: 500,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        widthHeightRatio:
                            0.8, // Tùy chỉnh tỉ lệ khung hình cho Card dự án
                        items: pageResult.items,
                        itemBuilder: (context, project) {
                          final baseItemsSearchParams = ProjectItemSearchParams(
                            projectId: project.id,
                          );
                          final projectOptionsSearchParams =
                              ProjectOptionSearchParams(projectId: project.id);

                          return ProjectCard(
                            project: project,
                            projectOptionPriceWidgets: Consumer(
                              builder: (context, ref, _) {
                                final baseItemsAsync = ref.watch(
                                  watchAllProjectItemsProvider(
                                    baseItemsSearchParams,
                                  ),
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
                                      const CircularProgressIndicator(),
                                  error: (e, s) => Text("Lỗi: $e"),
                                  data: (data) {
                                    final baseItems = data.$1;

                                    final projectOptions = data.$2;
                                    return Column(
                                      children: projectOptions
                                          .map(
                                            (option) => ProjectOptionPriceCard(
                                              option: option,
                                              baseitems: baseItems,
                                            ),
                                          )
                                          .toList(),
                                    );
                                  },
                                );
                              },
                            ),
                            onTap: () =>
                                ProjectAction.showDetail(context, project),
                            onEdit: () =>
                                ProjectAction.showEdit(context, ref, project),
                            onDelete: () =>
                                ProjectAction.showDelete(context, ref, project),
                          );
                        },
                      ),
                    ),

                    // Pagination
                    const SizedBox(height: 16),
                    AppPagination(
                      currentPage: pageResult.currentPage,
                      totalPages: pageResult.totalPages,
                      onPageChange: (page) {
                        searchParamsProvider.value = searchParamsProvider.value
                            .copyWith(page: page);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
