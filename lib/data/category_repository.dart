import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/extension/objectbox/query_string_property.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/search_params/category_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_repository.g.dart';

@riverpod
CategoryRepository categoryRepository(Ref ref) => CategoryRepository();

class CategoryRepository {
  final _categoryBox = ObjectboxService.instance.get<Category>();

  Stream<List<Category>> watchAll(CategorySearchParams? searchParams) {
    Condition<Category>? condition;
    condition = condition.safeAnd(
      searchParams?.name,
      Category_.name.containsIgnorecase,
    );

    final queryBuilder = _categoryBox.query(condition);
    return queryBuilder.watchQuery();
  }

  Stream<PageResult<Category>> watchPaged(CategorySearchParams searchParams) {
    Condition<Category>? condition;
    condition = condition.safeAnd(
      searchParams.name,
      Category_.name.containsIgnorecase,
    );
    final queryBuilder = _categoryBox.query(condition);

    return queryBuilder.watchPage(
      page: searchParams.page,
      size: searchParams.size,
    );
  }

  Future<void> add(Category category) async {
    Condition<Category>? duplicateCondition;

    duplicateCondition = duplicateCondition.safeAnd(
      category.name,
      Category_.name.equals,
    );

    final duplicateCategory = _categoryBox
        .query(duplicateCondition)
        .build()
        .findFirst();

    if (duplicateCategory != null) {
      throw EntityAlreadyExistsException(
        "Category với tên '${category.name}' đã tồn tại.",
      );
    }
    category.id = 0;
    _categoryBox.put(category);
  }

  Future<void> update(Category category) async {
    Condition<Category>? duplicateCondition;
    duplicateCondition = duplicateCondition
        .safeAnd(category.name, Category_.name.equals)
        .safeAnd(category.id, Category_.id.notEquals);

    final existingCategory = _categoryBox.get(category.id);
    if (existingCategory == null) {
      throw EntityNotFoundException(
        "Không tìm thấy Category với id '${category.id}'.",
      );
    }

    final duplicateCategory = _categoryBox
        .query(duplicateCondition)
        .build()
        .findFirst();
    if (duplicateCategory != null) {
      throw EntityAlreadyExistsException(
        "Category với tên '${category.name}' đã tồn tại.",
      );
    }

    _categoryBox.put(category);
  }

  Future<void> delete(int id) async {
    final existingCategory = _categoryBox.get(id);
    if (existingCategory == null) {
      throw EntityNotFoundException("Không tìm thấy Category với id '$id'.");
    }
    _categoryBox.remove(id);
  }
}
