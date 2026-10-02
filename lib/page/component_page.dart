import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/hook/use_page_effect.dart';
import 'package:component_companion/model/search_params/component_search_params.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/common/pagination.dart';
import 'package:component_companion/widget/component/component_action.dart';
import 'package:component_companion/widget/component/component_detail_panel.dart';
import 'package:component_companion/widget/component/component_filter_bar.dart';
import 'package:component_companion/widget/component/component_list_tile.dart';
import 'package:component_companion/widget/view/grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Danh sách linh kiện (trái) + chi tiết linh kiện đang chọn (phải).
class ComponentPage extends HookConsumerWidget {
  static const double _listWidth = 380;

  const ComponentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchParamsNotifier = useState(ComponentSearchParams(size: 20));
    final searchOptions = ref.watch(searchOptionsProvider);
    final params = searchParamsNotifier.value.copyWith(
      searchOptions: searchOptions,
    );
    final search = useMemoized(() => TextSearch(params.name, searchOptions), [
      params.name,
      searchOptions,
    ]);

    final controller = useScrollController();
    final selectedId = useState<int?>(null);

    final paged = usePagingEffect(
      pageResultAsync: ref.watch(watchComponentsProvider(params)),
      searchParamsNotifier: searchParamsNotifier,
    );
    final items = paged.result.asData?.value.items ?? const [];

    // Vừa thêm / nhân bản => chọn luôn
    useEffect(() {
      final focus = paged.focus;
      if (focus != null) selectedId.value = focus.id;
      return null;
    }, [paged.focus?.token]);

    // Chưa chọn gì (mới mở / vừa xoá) => chọn phần tử đầu trang
    final ids = items.map((c) => c.id).join(",");
    useEffect(() {
      if (selectedId.value == null && items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && selectedId.value == null) {
            selectedId.value = items.first.id;
          }
        });
      }
      return null;
    }, [ids, selectedId.value]);

    // Linh kiện đang chọn bị xoá => bỏ chọn để chọn lại
    final selectedAsync = selectedId.value == null
        ? null
        : ref.watch(watchComponentProvider(selectedId.value!));
    useEffect(() {
      if (selectedAsync case AsyncData(value: null)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) selectedId.value = null;
        });
      }
      return null;
    }, [selectedAsync]);

    // Cuộn tới phần tử được focus
    useEffect(() {
      final focus = paged.focus;
      if (focus == null) return null;
      final index = items.indexWhere((c) => c.id == focus.id);
      if (index < 0) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.hasClients) return;
        final position = controller.position;
        final top = index * ComponentListTile.height;
        if (top < position.pixels ||
            top + ComponentListTile.height >
                position.pixels + position.viewportDimension) {
          controller.animateTo(
            (top - position.viewportDimension / 3).clamp(
              0.0,
              position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      });
      return null;
    }, [paged.focus?.token, ids]);

    // ↑ / ↓ để chuyển linh kiện
    void move(int delta) {
      if (items.isEmpty) return;
      final index = items.indexWhere((c) => c.id == selectedId.value);
      final next = (index + delta).clamp(0, items.length - 1);
      selectedId.value = items[next].id;
      if (!controller.hasClients) return;
      final position = controller.position;
      final top = next * ComponentListTile.height;
      if (top < position.pixels) {
        controller.jumpTo(top);
      } else if (top + ComponentListTile.height >
          position.pixels + position.viewportDimension) {
        controller.jumpTo(
          top + ComponentListTile.height - position.viewportDimension,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
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
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Danh sách ---
                SizedBox(
                  width: _listWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: paged.result.when(
                      data: (pageResult) => Column(
                        children: [
                          Expanded(
                            child: pageResult.items.isEmpty
                                ? const Center(
                                    child: Text(
                                      "Không có linh kiện",
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  )
                                : Focus(
                                    onKeyEvent: (node, event) {
                                      if (event is! KeyDownEvent &&
                                          event is! KeyRepeatEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      if (event.logicalKey ==
                                          LogicalKeyboardKey.arrowDown) {
                                        move(1);
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey ==
                                          LogicalKeyboardKey.arrowUp) {
                                        move(-1);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: ListView.builder(
                                      controller: controller,
                                      padding: const EdgeInsets.all(6),
                                      itemExtent: ComponentListTile.height,
                                      itemCount: pageResult.items.length,
                                      itemBuilder: (context, index) {
                                        final item = pageResult.items[index];
                                        final tile = ComponentListTile(
                                          component: item,
                                          search: search,
                                          selected: item.id == selectedId.value,
                                          onTap: () =>
                                              selectedId.value = item.id,
                                        );
                                        if (paged.focus?.id != item.id) {
                                          return tile;
                                        }
                                        return FocusFlash(
                                          key: ValueKey((
                                            "component-flash",
                                            item.id,
                                            paged.focus!.token,
                                          )),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: tile,
                                        );
                                      },
                                    ),
                                  ),
                          ),
                          if (pageResult.totalPages > 1) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: AppPagination(
                                currentPage: pageResult.currentPage,
                                totalPages: pageResult.totalPages,
                                onPageChange: (page) {
                                  searchParamsNotifier.value =
                                      searchParamsNotifier.value.copyWith(
                                        page: page,
                                      );
                                  if (controller.hasClients) {
                                    controller.jumpTo(0);
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      error: (e, s) => AppErrorView(
                        message: "Đã có lỗi xảy ra khi tải linh kiện: $e",
                        onRetry: () =>
                            ref.invalidate(watchComponentsProvider(params)),
                      ),
                      loading: () => const AppLoadingView(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // --- Chi tiết ---
                Expanded(
                  child: selectedId.value == null
                      ? Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            "Chọn 1 linh kiện để xem chi tiết",
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ComponentDetailPanel(
                          key: ValueKey(selectedId.value),
                          componentId: selectedId.value!,
                          search: search,
                          onSelect: paged.focusOn,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
