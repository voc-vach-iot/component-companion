import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/notifier/component_type_notifier.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Load toàn bộ danh mục + loại linh kiện trước khi hiển thị form (dialog).
class CatalogLoader extends ConsumerWidget {
  final Widget Function(List<Category> categories, List<ComponentType> types)
  builder;

  const CatalogLoader({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(watchAllCategoriesProvider());
    final typesAsync = ref.watch(watchAllComponentTypesProvider());

    if (categoriesAsync.hasError || typesAsync.hasError) {
      return AppErrorView(
        message:
            "Lỗi khi tải danh mục / loại linh kiện: ${categoriesAsync.error ?? typesAsync.error}",
      );
    }

    final categories = categoriesAsync.asData?.value;
    final types = typesAsync.asData?.value;
    if (categories == null || types == null) return const AppLoadingView();

    return builder(categories, types);
  }
}
