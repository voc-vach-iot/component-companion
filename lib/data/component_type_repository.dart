import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/search_params/component_type_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'component_type_repository.g.dart';

@riverpod
ComponentTypeRepository componentTypeRepository(Ref ref) =>
    ComponentTypeRepository();

class ComponentTypeRepository {
  final _db = ObjectboxService.instance;
  final _typeBox = ObjectboxService.instance.get<ComponentType>();

  // Loại hiển thị kèm tên/màu danh mục nên phải lắng nghe cả bảng Category
  Stream<void> _watchTables() => _db.watchTables([
    _db.store.watch<ComponentType>(),
    _db.store.watch<Category>(),
  ]);

  /// Lọc tên trong Dart vì cần bỏ dấu / khớp nhiều từ mà ObjectBox không hỗ trợ.
  List<ComponentType> _find(ComponentTypeSearchParams searchParams) {
    final search = TextSearch(searchParams.name, searchParams.searchOptions);
    // ObjectBox không hỗ trợ order theo thuộc tính quan hệ (categoryId)
    final items = (_typeBox.query()..order(ComponentType_.name)).findAndClose();
    return search.filter(items, (t) => t.name);
  }

  Stream<List<ComponentType>> watchAll(
    ComponentTypeSearchParams? searchParams,
  ) {
    searchParams ??= ComponentTypeSearchParams();
    return _watchTables().map((_) => _find(searchParams!));
  }

  Stream<PageResult<ComponentType>> watchPaged(
    ComponentTypeSearchParams searchParams,
  ) {
    return _watchTables().map(
      (_) => _find(searchParams).toPage(
        page: searchParams.page,
        size: searchParams.size,
        focusId: searchParams.focusId,
        idOf: (t) => t.id,
      ),
    );
  }

  /// Loại khác (khác [excludeId]) đang sở hữu [keyword], null nếu chưa ai dùng.
  ComponentType? findKeywordOwner(String keyword, {int excludeId = 0}) {
    final normalized = KeywordMatcher.normalize(keyword);
    if (normalized.isEmpty) return null;
    return _typeBox
        .query(
          ComponentType_.keywords.containsElement(normalized) &
              ComponentType_.id.notEquals(excludeId),
        )
        .findFirstAndClose();
  }

  Future<int> add(ComponentType type) async {
    final duplicateType = _typeBox
        .query(ComponentType_.name.equals(type.name))
        .findFirstAndClose();
    if (duplicateType != null) {
      throw EntityAlreadyExistsException(
        "Loại linh kiện với tên '${type.name}' đã tồn tại.",
      );
    }

    type.id = 0;
    _validateKeywords(type);
    return _typeBox.put(type);
  }

  Future<int> update(ComponentType type) async {
    final existingType = _typeBox.get(type.id);
    if (existingType == null) {
      throw EntityNotFoundException(
        "Không tìm thấy loại linh kiện với id '${type.id}'.",
      );
    }

    final duplicateType = _typeBox
        .query(
          ComponentType_.name.equals(type.name) &
              ComponentType_.id.notEquals(type.id),
        )
        .findFirstAndClose();
    if (duplicateType != null) {
      throw EntityAlreadyExistsException(
        "Loại linh kiện với tên '${type.name}' đã tồn tại.",
      );
    }

    _validateKeywords(type);
    return _typeBox.put(type);
  }

  Future<bool> delete(int id) async {
    final existingType = _typeBox.get(id);
    if (existingType == null) {
      throw EntityNotFoundException(
        "Không tìm thấy loại linh kiện với id '$id'.",
      );
    }
    return _typeBox.remove(id);
  }

  /// Chuẩn hóa keyword và đảm bảo không keyword nào đã thuộc loại khác.
  void _validateKeywords(ComponentType type) {
    type.keywords = KeywordMatcher.normalizeAll(type.keywords);
    for (final keyword in type.keywords) {
      final owner = findKeywordOwner(keyword, excludeId: type.id);
      if (owner != null) {
        throw EntityAlreadyExistsException(
          "Từ khóa '$keyword' đã thuộc loại '${owner.name}'.",
        );
      }
    }
  }
}
