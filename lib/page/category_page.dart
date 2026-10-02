import 'package:component_companion/hook/use_page_effect.dart';
import 'package:component_companion/model/search_params/category_search_params.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/category/category_action.dart';
import 'package:component_companion/widget/category/category_card.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/view/grid_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CategoryPage extends HookConsumerWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchParamsNotifier = useState(CategorySearchParams());
    final searchOptions = ref.watch(searchOptionsProvider);
    final params = searchParamsNotifier.value.copyWith(
      searchOptions: searchOptions,
    );
    final search = useMemoized(() => TextSearch(params.name, searchOptions), [
      params.name,
      searchOptions,
    ]);

    final controller = useScrollController();

    final paged = usePagingEffect(
      pageResultAsync: ref.watch(watchCategoriesProvider(params)),
      searchParamsNotifier: searchParamsNotifier,
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header đã được gộp lại
          AppHeader(
            title: "Quản lý danh mục".toUpperCase(),
            onSearch: (value) {
              searchParamsNotifier.value = searchParamsNotifier.value.copyWith(
                name: value,
                page: 0,
              );
            },
            onAddPressed: () =>
                CategoryAction.showAdd(context, ref, onSuccess: paged.focusOn),
          ),

          const SizedBox(height: 16),
          Expanded(
            child: paged.result.when(
              data: (pageResult) {
                return Column(
                  children: [
                    Expanded(
                      child: GenericGrid(
                        maxWidth: 250,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        widthHeightRatio: 1,
                        scrollController: controller,
                        focus: paged.focus,
                        idOf: (item) => item.id,
                        items: pageResult.items,
                        itemBuilder: (context, category) => CategoryCard(
                          category: category,
                          search: search,
                          onEdit: () =>
                              CategoryAction.showEdit(context, ref, category),
                          onDelete: () =>
                              CategoryAction.showDelete(context, ref, category),
                        ),
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
              error: (e, s) => AppErrorView(message: "Lỗi tải danh mục: $e"),
              loading: () => const AppLoadingView(),
            ),
          ),
        ],
      ),
    );
  }
}
