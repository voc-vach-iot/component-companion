import 'package:component_companion/hook/use_page_effect.dart';
import 'package:component_companion/model/search_params/component_option_search_params.dart';
import 'package:component_companion/model/search_params/component_search_params.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/notifier/component_option_notifier.dart';
import 'package:component_companion/util/scroll.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
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
    final searchParamsNotifier = useState(ComponentSearchParams());
    final pageResultAsync = ref.watch(
      watchComponentsProvider(searchParamsNotifier.value),
    );

    final controller = useScrollController();

    usePagingEffect(
      pageResultAsync: pageResultAsync,
      searchParamsNotifier: searchParamsNotifier,
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header đã được gộp lại
          AppHeader(
            title: "Quản lý linh kiện".toUpperCase(),
            onSearch: (value) {
              searchParamsNotifier.value = searchParamsNotifier.value.copyWith(
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
                      () =>
                      pageResult.items
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
                                scrollController: controller,
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
                                              shrinkWrap: false,
                                              // Bỏ shrinkWrap để tối ưu hiệu năng nếu danh sách dài
                                              physics: const BouncingScrollPhysics(),
                                              // Cho phép cuộn mượt mà
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
                                                      ComponentOptionAction
                                                          .showEdit(
                                                        context,
                                                        ref,
                                                        item,
                                                        option,
                                                      ),
                                                  onDelete: () =>
                                                      ComponentOptionAction
                                                          .showDelete(
                                                        context,
                                                        ref,
                                                        option,
                                                      ),
                                                );
                                              },
                                            );
                                          },
                                          loading: () => const AppLoadingView(),
                                          error: (e, s) =>
                                              AppErrorView(
                                                message: "Lỗi khi tải tùy chọn: $e",
                                              ),
                                        );
                                      },
                                    ),
                                    onAddOption: () =>
                                        ComponentOptionAction.showAdd(
                                          context,
                                          ref,
                                          item,
                                          onSuccess: () {
                                            ScrollUtils.scrollToBottom(
                                              controller,
                                            );
                                          },
                                        ),
                                  );
                                },
                              );
                            },
                            loading: () => const AppLoadingView(),
                            error: (e, s) =>
                                AppErrorView(
                                  message: "Lỗi khi tải danh mục: $e",
                                ),
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
                        searchParamsNotifier.value = searchParamsNotifier.value
                            .copyWith(page: page);
                      },
                    ),
                  ],
                );
              },
              error: (e, s) {
                return AppErrorView(
                  message: "Đã có lỗi xảy ra khi tải linh kiện: $e",
                  onRetry: () {
                    // Thử reload lại bằng cách reset searchParamsProvider
                    searchParamsNotifier.value = searchParamsNotifier.value
                        .copyWith(
                      // Không cần thay đổi gì, chỉ cần trigger lại provider
                    );
                  },
                );
              },
              loading: () => const AppLoadingView(),
            ),
          ),
        ],
      ),
    );
  }
}
