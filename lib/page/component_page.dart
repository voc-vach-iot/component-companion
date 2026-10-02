import 'package:component_companion/hook/use_page_effect.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/search_params/component_option_search_params.dart';
import 'package:component_companion/model/search_params/component_search_params.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/notifier/component_option_notifier.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/view/grid_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/pagination.dart';
import 'package:component_companion/widget/component/component_action.dart';
import 'package:component_companion/widget/component/component_card.dart';
import 'package:component_companion/widget/component/component_filter_bar.dart';
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
      pageResultAsync: ref.watch(watchComponentsProvider(params)),
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
                page: 0,
              );
            },
            onAddPressed: () =>
                ComponentAction.showAdd(context, ref, onSuccess: paged.focusOn),
          ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ComponentFilterBar(
              params: searchParamsNotifier.value,
              total: paged.result.asData?.value.totalItems,
              onChanged: (next) => searchParamsNotifier.value = next,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: paged.result.when(
              data: (pageResult) {
                return Column(
                  children: [
                    Expanded(
                      child: GenericGrid(
                        maxWidth: 500,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        widthHeightRatio: 1,
                        scrollController: controller,
                        focus: paged.focus,
                        idOf: (item) => item.id,
                        items: pageResult.items,
                        itemBuilder: (context, item) {
                          return ComponentCard(
                            component: item,
                            // Repository đã lắng nghe bảng Category nên đọc trực tiếp quan hệ
                            category: item.category.target,
                            search: search,
                            onEditComponent: () =>
                                ComponentAction.showEdit(context, ref, item),
                            onDeleteComponent: () =>
                                ComponentAction.showDelete(context, ref, item),
                            onEditStock: () =>
                                ComponentAction.showStock(context, ref, item),
                            onCloneComponent: () => ComponentAction.clone(
                              context,
                              ref,
                              item,
                              onSuccess: paged.focusOn,
                            ),
                            componentOptionsWidget: _ComponentOptionList(
                              component: item,
                            ),
                            onAddOption: () => ComponentOptionAction.showAdd(
                              context,
                              ref,
                              item,
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
                  onRetry: () =>
                      ref.invalidate(watchComponentsProvider(params)),
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

/// Danh sách tuỳ chọn trong card linh kiện. Khi có tuỳ chọn mới (thêm / nhân bản)
/// thì tự cuộn tới và nháy sáng tuỳ chọn đó.
class _ComponentOptionList extends HookConsumerWidget {
  final Component component;

  const _ComponentOptionList({required this.component});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = useKeepPreviousData(
      ref.watch(
        watchAllComponentOptionsProvider(
          ComponentOptionSearchParams(componentId: component.id),
        ),
      ),
    );
    final controller = useScrollController();
    final knownIds = useRef<Set<int>?>(null);
    final newIds = useState<Set<int>>(const {});

    final options = optionsAsync.asData?.value;
    useEffect(() {
      if (options == null) return null;
      final ids = options.map((o) => o.id).toSet();
      final previous = knownIds.value;
      knownIds.value = ids;
      // Lần tải đầu không coi là "mới"
      if (previous == null) return null;

      final added = ids.difference(previous);
      if (added.isEmpty) return null;
      newIds.value = added;
      final index = options.indexWhere((o) => added.contains(o.id));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.hasClients) return;
        // Tuỳ chọn mới thường nằm cuối danh sách (id tăng dần)
        final position = controller.position;
        final target = index == options.length - 1
            ? position.maxScrollExtent
            : (index * 64.0).clamp(0.0, position.maxScrollExtent);
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      });
      return null;
    }, [options]);

    return optionsAsync.when(
      data: (options) => ListView.separated(
        controller: controller,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final card = ComponentOptionCard(
            option: option,
            onEdit: () =>
                ComponentOptionAction.showEdit(context, ref, component, option),
            onDelete: () =>
                ComponentOptionAction.showDelete(context, ref, option),
            onClone: () => ComponentOptionAction.clone(context, ref, option),
            onConfirmPrice: () =>
                ComponentOptionAction.confirmPrice(context, ref, option),
            onShowHistory: () =>
                ComponentOptionAction.showHistory(context, option),
            // Danh sách đã sắp rẻ nhất trước
            isCheapest: options.length > 1 && index == 0,
          );
          if (!newIds.value.contains(option.id)) return card;
          return FocusFlash(
            key: ValueKey(("option-flash", option.id)),
            borderRadius: BorderRadius.circular(8),
            child: card,
          );
        },
      ),
      loading: () => const AppLoadingView(),
      error: (e, s) => AppErrorView(message: "Lỗi khi tải tùy chọn: $e"),
    );
  }
}
