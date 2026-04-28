import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/search_params/component_search_params.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/widget/common/grid_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/pagination.dart';
import 'package:component_companion/widget/component/add_component_dialog.dart';
import 'package:component_companion/widget/component/component_item.dart';
import 'package:component_companion/widget/component/component_option_item.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
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
            onAddPressed: () => _onAddComponent(context, ref),
          ),

          const SizedBox(height: 16),
          Expanded(
            child: pageResultAsync.when(
              data: (data) {
                return Column(
                  children: [
                    Expanded(
                      child: GenericGrid(
                        maxWidth: 500,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        widthHeightRatio: 1,
                        items: data.items,
                        itemBuilder: (context, item) => ComponentItem(
                          component: item,
                          onEdit: () => _onEdit(context, ref, item),
                          onDelete: () => _onDelete(context, ref, item),
                          optionBuilder: (componentOption) =>
                              ComponentOptionItem(
                                option: componentOption,
                                onEdit: () {},
                                onDelete: () {},
                              ),
                        ),
                      ),
                    ),

                    // --- PAGINATION ---
                    const SizedBox(height: 16),
                    AppPagination(
                      currentPage: data.currentPage,
                      totalPages: data.totalPages,
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

  void _onAddComponent(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        // Gói trong Consumer để đảm bảo ref.watch hoạt động đúng
        return Consumer(
          builder: (context, ref, child) {
            final categoriesAsync = ref.watch(watchAllCategoriesProvider());

            return categoriesAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => AlertDialog(content: Text("Lỗi: $err")),
              data: (categories) {
                return AddComponentDialog(
                  categories: categories,
                  onAdd: (newComponent) async {
                    final id = await ref
                        .read(componentProvider.notifier)
                        .addComponent(newComponent)
                        .withToast(context);
                    if (context.mounted && id != null) {
                      AppSnackBar.show(
                        context,
                        message: "Thêm linh kiện thành công",
                        type: SnackBarType.success,
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _onEdit(BuildContext context, WidgetRef ref, Component component) {
    debugPrint("Nhấn sửa danh mục ${component.name}");
  }

  void _onDelete(BuildContext context, WidgetRef ref, Component component) {
    showDialog(
      context: context,
      builder: (context) => ConfirmDeleteDialog(
        title: "Xóa danh mục",
        content:
            "Bạn có chắc chắn muốn xóa linh kiện '${component.name}' không? Hành động này không thể hoàn tác.",
        onConfirm: () async {
          // Gọi tới Provider để thực hiện xóa trong DB
          final success =
              await ref
                  .read(componentProvider.notifier)
                  .deleteComponent(component.id)
                  .withToast(context) ??
              false;

          if (context.mounted && success) {
            AppSnackBar.show(
              context,
              message: "Đã xóa linh kiện thành công!",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }
}
