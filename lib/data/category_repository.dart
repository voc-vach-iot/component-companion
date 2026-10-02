import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/search_params/category_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_repository.g.dart';

@riverpod
CategoryRepository categoryRepository(Ref ref) => CategoryRepository();

class CategoryRepository {
  final _categoryBox = ObjectboxService.instance.get<Category>();

  Stream<List<Category>> watchAll(CategorySearchParams? searchParams) {
    searchParams ??= CategorySearchParams();
    final search = TextSearch(searchParams.name, searchParams.searchOptions);

    return _categoryBox.query().watchQuery().map(
      (items) => search.filter(items, (c) => c.name),
    );
  }

  Stream<PageResult<Category>> watchPaged(CategorySearchParams searchParams) {
    // Lọc trong Dart vì cần bỏ dấu / khớp nhiều từ mà ObjectBox không hỗ trợ
    final search = TextSearch(searchParams.name, searchParams.searchOptions);

    return _categoryBox.query().watchQuery().map(
      (items) => search
          .filter(items, (c) => c.name)
          .toPage(
            page: searchParams.page,
            size: searchParams.size,
            focusId: searchParams.focusId,
            idOf: (c) => c.id,
          ),
    );
  }

  Stream<Map<int, Category>> watchMapByIds(List<int> ids) {
    final queryBuilder = _categoryBox.query(Category_.id.oneOf(ids));
    return queryBuilder.watchQueryAsMap();
  }

  Stream<Category?> watchById(int id) {
    final queryBuilder = _categoryBox.query(Category_.id.equals(id));
    return queryBuilder.watchSingle();
  }

  /// Danh mục khác (khác [excludeId]) đang sở hữu [keyword], null nếu chưa ai dùng.
  Category? findKeywordOwner(String keyword, {int excludeId = 0}) {
    final normalized = KeywordMatcher.normalize(keyword);
    if (normalized.isEmpty) return null;
    return _categoryBox
        .query(
          Category_.keywords.containsElement(normalized) &
              Category_.id.notEquals(excludeId),
        )
        .findFirstAndClose();
  }

  Future<int> add(Category category) async {
    Condition<Category>? duplicateCondition;

    duplicateCondition = duplicateCondition.safeAnd(
      category.name,
      Category_.name.equals,
    );

    final duplicateCategory = _categoryBox
        .query(duplicateCondition)
        .findFirstAndClose();

    if (duplicateCategory != null) {
      throw EntityAlreadyExistsException(
        "Category với tên '${category.name}' đã tồn tại.",
      );
    }
    category.id = 0;
    _validateKeywords(category);
    return _categoryBox.put(category);
  }

  Future<int> update(Category category) async {
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
        .findFirstAndClose();
    if (duplicateCategory != null) {
      throw EntityAlreadyExistsException(
        "Category với tên '${category.name}' đã tồn tại.",
      );
    }

    _validateKeywords(category);
    return _categoryBox.put(category);
  }

  Future<bool> delete(int id) async {
    final existingCategory = _categoryBox.get(id);
    if (existingCategory == null) {
      throw EntityNotFoundException("Không tìm thấy Category với id '$id'.");
    }
    return _categoryBox.remove(id);
  }

  /// Chuẩn hóa keyword và đảm bảo không keyword nào đã thuộc danh mục khác.
  void _validateKeywords(Category category) {
    category.keywords = KeywordMatcher.normalizeAll(category.keywords);
    for (final keyword in category.keywords) {
      final owner = findKeywordOwner(keyword, excludeId: category.id);
      if (owner != null) {
        throw EntityAlreadyExistsException(
          "Từ khóa '$keyword' đã thuộc danh mục '${owner.name}'.",
        );
      }
    }
  }
}
