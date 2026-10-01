import 'package:component_companion/hook/use_page_effect.dart';
import 'package:component_companion/model/search_params/component_type_search_params.dart';
import 'package:component_companion/notifier/component_type_notifier.dart';
import 'package:component_companion/util/scroll.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/common/pagination.dart';
import 'package:component_companion/widget/component_type/component_type_action.dart';
import 'package:component_companion/widget/component_type/component_type_card.dart';
import 'package:component_companion/widget/view/grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ComponentTypePage extends HookConsumerWidget {
  const ComponentTypePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchParamsNotifier = useState(ComponentTypeSearchParams());
    final pageResultAsync = ref.watch(
      watchComponentTypesProvider(searchParamsNotifier.value),
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
          AppHeader(
            title: "Quản lý loại linh kiện".toUpperCase(),
            onSearch: (value) {
              searchParamsNotifier.value = searchParamsNotifier.value.copyWith(
                name: value,
              );
            },
            onAddPressed: () => ComponentTypeAction.showAdd(
              context,
              ref,
              onSuccess: () => ScrollUtils.scrollToBottom(controller),
            ),
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
                        scrollController: controller,
                        items: pageResult.items,
                        itemBuilder: (context, type) => ComponentTypeCard(
                          type: type,
                          onEdit: () =>
                              ComponentTypeAction.showEdit(context, ref, type),
                          onDelete: () => ComponentTypeAction.showDelete(
                            context,
                            ref,
                            type,
                          ),
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
              error: (e, s) =>
                  AppErrorView(message: "Lỗi tải loại linh kiện: $e"),
              loading: () => const AppLoadingView(),
            ),
          ),
        ],
      ),
    );
  }
}
