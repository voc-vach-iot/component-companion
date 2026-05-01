import 'package:component_companion/enum/category_color.dart';
import 'package:component_companion/enum/category_icon.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/extension/objectbox/query_string_property.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/search_params/category_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter/rendering.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_repository.g.dart';

@riverpod
CategoryRepository categoryRepository(Ref ref) => CategoryRepository();

class CategoryRepository {
  final _categoryBox = ObjectboxService.instance.get<Category>();

  Stream<List<Category>> watchAll(CategorySearchParams? searchParams) {
    searchParams ??= CategorySearchParams();

    Condition<Category>? condition;
    condition = condition.safeAnd(
      searchParams.name,
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

  Stream<Map<int, Category>> watchMapByIds(List<int> ids) {
    final queryBuilder = _categoryBox.query(Category_.id.oneOf(ids));
    return queryBuilder.watchQueryAsMap();
  }

  Stream<Category?> watchById(int id) {
    debugPrint("Watching Category with id: $id");
    final queryBuilder = _categoryBox.query(Category_.id.equals(id));
    return queryBuilder.watchSingle();
  }

  Future<void> initDefaultCategories() async {
    // 1. Chỉ khởi tạo nếu database trống để tránh trùng lặp khi app khởi động lại
    if (!_categoryBox.isEmpty()) {
      return;
    }

    // 2. Lấy ra các giá trị mặc định từ Enum
    final defaultColors = CategoryColor.values
        .where((c) => c.isDefault)
        .toList();
    final defaultIcons = CategoryIcon.values.where((i) => i.isDefault).toList();

    // 3. Tạo danh sách Category dựa trên sự kết hợp (hoặc logic riêng của bạn)
    final List<Category> defaultCategories = [];

    // Ví dụ: Tạo danh mục dựa trên các icon mặc định và gán màu xoay vòng
    for (int i = 0; i < defaultIcons.length; i++) {
      final icon = defaultIcons[i];
      // Dùng toán tử modulo (%) để xoay vòng màu nếu số lượng icon > số lượng màu
      final color = defaultColors[i % defaultColors.length];

      defaultCategories.add(
        Category(
          name: icon.label, // Hoặc đặt tên theo logic của bạn
          colorValue: color.color.toARGB32(),
          iconName: icon.toValue(),
        ),
      );
    }

    // 4. Lưu vào database
    _categoryBox.putMany(defaultCategories);
  }

  Future<int> add(Category category) async {
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
        .build()
        .findFirst();
    if (duplicateCategory != null) {
      throw EntityAlreadyExistsException(
        "Category với tên '${category.name}' đã tồn tại.",
      );
    }

    return _categoryBox.put(category);
  }

  Future<bool> delete(int id) async {
    final existingCategory = _categoryBox.get(id);
    if (existingCategory == null) {
      throw EntityNotFoundException("Không tìm thấy Category với id '$id'.");
    }
    return _categoryBox.remove(id);
  }
}
