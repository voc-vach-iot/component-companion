import 'package:component_companion/model/search_params/category_search_params.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/widget/category/category_action.dart';
import 'package:component_companion/widget/category/category_card.dart';
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
    final searchParamsProvider = useState(CategorySearchParams());
    final pageResultAsync = ref.watch(
      watchCategoriesProvider(searchParamsProvider.value),
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header đã được gộp lại
          AppHeader(
            title: "Quản lý danh mục".toUpperCase(),
            onSearch: (value) {
              searchParamsProvider.value = searchParamsProvider.value.copyWith(
                name: value,
              );
            },
            onAddPressed: () => CategoryAction.showAdd(context, ref),
          ),

          const SizedBox(height: 16),
          Expanded(
            child: pageResultAsync.when(
              data: (pageResult) {
                return Column(
                  children: [
                    Expanded(
                      child: GenericGrid(
                        maxWidth: 250,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        widthHeightRatio: 1,
                        items: pageResult.items,
                        itemBuilder: (context, category) => CategoryCard(
                          category: category,
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
