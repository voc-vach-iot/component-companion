import 'package:component_companion/data/category_repository.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/search_params/category_search_params.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_notifier.g.dart';

@riverpod
class CategoryNotifier extends _$CategoryNotifier {
  @override
  void build() {}

  Future<int> addCategory(Category category) async {
    final categoryRepository = ref.read(categoryRepositoryProvider);
    return await categoryRepository.add(category);
  }

  Future<int> updateCategory(Category category) async {
    final categoryRepository = ref.read(categoryRepositoryProvider);
    return await categoryRepository.update(category);
  }

  Future<bool> deleteCategory(int id) async {
    final categoryRepository = ref.read(categoryRepositoryProvider);
    return await categoryRepository.delete(id);
  }
}

@riverpod
Stream<List<Category>> watchAllCategories(
  Ref ref, {
  CategorySearchParams? searchParams,
}) {
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  return categoryRepository.watchAll(searchParams);
}

@riverpod
Stream<PageResult<Category>> watchCategories(
  Ref ref,
  CategorySearchParams searchParams,
) {
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  return categoryRepository.watchPaged(searchParams);
}
