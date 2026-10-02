import 'package:component_companion/hook/use_page_effect.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/notifier/shop_notifier.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/shop/shop_action.dart';
import 'package:component_companion/widget/shop/shop_card.dart';
import 'package:component_companion/widget/view/grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Quản lý shop: đổi tên 1 chỗ là mọi tuỳ chọn mua cập nhật theo, gộp các tên
/// trùng của cùng 1 shop.
class ShopPage extends HookConsumerWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = useState("");
    final searchOptions = ref.watch(searchOptionsProvider);
    final search = useMemoized(() => TextSearch(name.value, searchOptions), [
      name.value,
      searchOptions,
    ]);
    final shopsAsync = useKeepPreviousData(
      ref.watch(
        watchAllShopsProvider(name: name.value, searchOptions: searchOptions),
      ),
    );

    final focus = useState<FocusTarget?>(null);
    void focusOn(int id) {
      final target = (id: id, token: (focus.value?.token ?? 0) + 1);
      focus.value = target;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (context.mounted && focus.value == target) focus.value = null;
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          AppHeader(
            title: "Quản lý shop".toUpperCase(),
            onSearch: (value) => name.value = value,
            onAddPressed: () async {
              final shop = await ShopAction.showAdd(context, ref);
              if (shop != null) focusOn(shop.id);
            },
          ),
          Expanded(
            child: shopsAsync.when(
              data: (shops) => GenericGrid(
                maxWidth: 420,
                widthHeightRatio: 4.4,
                focus: focus.value,
                idOf: (shop) => shop.id,
                items: shops,
                itemBuilder: (context, shop) => ShopCard(
                  shop: shop,
                  search: search,
                  onEdit: () => ShopAction.showEdit(context, ref, shop),
                  onMerge: () => ShopAction.showMerge(context, ref, shop),
                  onDelete: () => ShopAction.showDelete(context, ref, shop),
                ),
              ),
              error: (e, s) => AppErrorView(message: "Lỗi tải shop: $e"),
              loading: () => const AppLoadingView(),
            ),
          ),
        ],
      ),
    );
  }
}
