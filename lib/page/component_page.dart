import 'package:component_companion/model/search_params/component_option_search_params.dart';
import 'package:component_companion/model/search_params/component_search_params.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/notifier/component_option_notifier.dart';
import 'package:component_companion/widget/view/grid_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/pagination.dart';
import 'package:component_companion/widget/component/component_action.dart';
import 'package:component_companion/widget/component/component_card.dart';
import 'package:component_companion/widget/component/component_option_action.dart';
import 'package:component_companion/widget/component/component_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ComponentPage extends HookConsumerWidget {
  const ComponentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchParamsProvider = useState(ComponentSearchParams());
    final pageResultAsync = ref.watch(
      watchComponentsProvider(searchParamsProvider.value),
    );
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header đã được gộp lại
          AppHeader(
            title: "Quản lý linh kiện".toUpperCase(),
            onSearch: (value) {
              searchParamsProvider.value = searchParamsProvider.value.copyWith(
                name: value,
              );
            },
            onAddPressed: () => ComponentAction.showAdd(context, ref),
          ),

          const SizedBox(height: 16),
          Expanded(
            child: pageResultAsync.when(
              data: (pageResult) {
                final categoryIds = useMemoized(
                  () => pageResult.items
                      .map((item) => item.category.targetId)
                      .toSet()
                      .toList(),
                  [pageResult],
                );
                final categoriesMapAsync = ref.watch(
                  watchCategoryMapByIdsProvider(categoryIds),
                );
                return Column(
                  children: [
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          return categoriesMapAsync.when(
                            data: (categoriesMap) {
                              return GenericGrid(
                                maxWidth: 500,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                widthHeightRatio: 1,
                                items: pageResult.items,
                                itemBuilder: (context, item) {
                                  return ComponentCard(
                                    component: item,
                                    category:
                                        categoriesMap[item.category.targetId],
                                    onEditComponent: () =>
                                        ComponentAction.showEdit(
                                          context,
                                          ref,
                                          item,
                                        ),
                                    onDeleteComponent: () =>
                                        ComponentAction.showDelete(
                                          context,
                                          ref,
                                          item,
                                        ),
                                    componentOptionsWidget: Consumer(
                                      builder: (context, ref, child) {
                                        final searchParams =
                                            ComponentOptionSearchParams(
                                              componentId: item.id,
                                            );
                                        final optionsAsync = ref.watch(
                                          watchAllComponentOptionsProvider(
                                            searchParams,
                                          ),
                                        );

                                        return optionsAsync.when(
                                          data: (options) {
                                            // 1. KHÔNG dùng Expanded ở đây
                                            // 2. Dùng shrinkWrap và NeverScrollableScrollPhysics để ListView nằm êm trong Card
                                            return ListView.separated(
                                              shrinkWrap:
                                                  true, // Quan trọng: Để ListView co lại theo số lượng item
                                              physics:
                                                  const NeverScrollableScrollPhysics(), // Để nó cuộn theo Grid cha
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              itemCount: options.length,
                                              separatorBuilder:
                                                  (context, index) =>
                                                      const SizedBox(height: 8),
                                              itemBuilder: (context, index) {
                                                final option = options[index];
                                                return ComponentOptionCard(
                                                  option: option,
                                                  onEdit: () =>
                                                      ComponentOptionAction.showEdit(
                                                        context,
                                                        ref,
                                                        item,
                                                        option,
                                                      ),
                                                  onDelete: () =>
                                                      ComponentOptionAction.showDelete(
                                                        context,
                                                        ref,
                                                        option,
                                                      ),
                                                );
                                              },
                                            );
                                          },
                                          loading: () => const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                          error: (e, s) => const Text(
                                            "Không thể tải tùy chọn",
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        );
                                      },
                                    ),
                                    onAddOption: () =>
                                        ComponentOptionAction.showAdd(
                                          context,
                                          ref,
                                          item,
                                        ),
                                  );
                                },
                              );
                            },
                            loading: () => const CircularProgressIndicator(),
                            error: (e, s) {
                              debugPrint("Lỗi khi tải danh mục: $e");
                              return const Text("Không thể tải danh mục");
                            },
                          );
                        },
                      ),
                    ),

                    // --- PAGINATION ---
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
              error: (e, s) {
                debugPrint("Lỗi khi tải danh mục: $e");
                return Center(child: Text("Đã có lỗi xảy ra"));
              },
              loading: () => const CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
