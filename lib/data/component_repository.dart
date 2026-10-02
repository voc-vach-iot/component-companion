import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/search_params/component_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/util/copy_name.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'component_repository.g.dart';

@riverpod
ComponentRepository componentRepository(Ref ref) => ComponentRepository();

class ComponentRepository {
  final _db = ObjectboxService.instance;
  final _componentBox = ObjectboxService.instance.get<Component>();

  // Card linh kiện hiển thị màu danh mục, icon của loại, tồn kho, giá rẻ nhất
  // nên phải lắng nghe cả các bảng liên quan
  Stream<void> _watchTables({bool includeProjectItem = false}) =>
      _db.watchTables([
        _db.store.watch<Component>(),
        _db.store.watch<Category>(),
        _db.store.watch<ComponentType>(),
        _db.store.watch<StockItem>(),
        _db.store.watch<ComponentOption>(),
        if (includeProjectItem) _db.store.watch<ProjectItem>(),
      ]);

  Stream<List<Component>> watchAll(ComponentSearchParams? searchParams) {
    searchParams ??= ComponentSearchParams();
    final search = TextSearch(searchParams.name, searchParams.searchOptions);

    return _watchTables().map((_) {
      final allItems = search.filter(
        _componentBox.query().findAndClose(),
        (c) => c.name,
      );

      allItems.sort((a, b) {
        final cagetoryId1 = a.category.targetId;
        final categoryId2 = b.category.targetId;
        return cagetoryId1.compareTo(categoryId2);
      });

      return allItems;
    });
  }

  QueryBuilder<Component> _pagedQuery(ComponentSearchParams searchParams) {
    Condition<Component>? condition;
    if (searchParams.categoryIds.isNotEmpty) {
      condition = Component_.category.anyOf(searchParams.categoryIds);
    }
    if (searchParams.typeIds.isNotEmpty) {
      final byType = Component_.type.anyOf(searchParams.typeIds);
      condition = condition == null ? byType : condition & byType;
    }
    final queryBuilder = _componentBox.query(condition);

    queryBuilder
        .safeBacklink(
          searchParams.projectId,
          ProjectItem_.component,
          ProjectItem_.project.equals,
        )
        .safeBacklink(
          searchParams.projectOptionId,
          ProjectItem_.component,
          ProjectItem_.projectOption.equals,
        );
    return queryBuilder;
  }

  Stream<PageResult<Component>> watchPaged(ComponentSearchParams searchParams) {
    final filterByProject =
        searchParams.projectId != null || searchParams.projectOptionId != null;

    // Lọc tên trong Dart vì cần bỏ dấu / khớp nhiều từ mà ObjectBox không hỗ trợ
    final search = TextSearch(searchParams.name, searchParams.searchOptions);

    return _watchTables(includeProjectItem: filterByProject).map((_) {
      final items = search
          .filter(_pagedQuery(searchParams).findAndClose(), (c) => c.name)
          .where((c) => _matchStock(c, searchParams.stockFilter))
          .toList();
      _sort(items, searchParams.sort);
      return items.toPage(
        page: searchParams.page,
        size: searchParams.size,
        focusId: searchParams.focusId,
        idOf: (c) => c.id,
      );
    });
  }

  static bool _matchStock(Component c, StockFilter filter) {
    final total = c.stockTotal;
    return switch (filter) {
      StockFilter.all => true,
      StockFilter.untracked => total == null,
      StockFilter.out => total == 0,
      StockFilter.inStock => total != null && total > 0,
      StockFilter.low =>
        total != null &&
            c.lowStockThreshold > 0 &&
            total <= c.lowStockThreshold,
    };
  }

  /// Đơn giá rẻ nhất trong các tuỳ chọn (null nếu chưa có tuỳ chọn nào).
  static double? cheapestUnitPrice(Component c) {
    double? best;
    for (final o in c.options) {
      if (best == null || o.pricePerUnit < best) best = o.pricePerUnit;
    }
    return best;
  }

  static void _sort(List<Component> items, ComponentSort sort) {
    int byNullable<T extends Comparable>(T? a, T? b, {bool desc = false}) {
      if (a == null && b == null) return 0;
      if (a == null) return 1; // null luôn ở cuối
      if (b == null) return -1;
      return desc ? b.compareTo(a) : a.compareTo(b);
    }

    switch (sort) {
      case ComponentSort.added:
        break;
      case ComponentSort.newest:
        items.sort((a, b) => b.id.compareTo(a.id));
      case ComponentSort.nameAsc:
        items.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case ComponentSort.category:
        items.sort((a, b) {
          final byCategory = byNullable(
            a.category.target?.name.toLowerCase(),
            b.category.target?.name.toLowerCase(),
          );
          return byCategory != 0
              ? byCategory
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case ComponentSort.priceAsc || ComponentSort.priceDesc:
        final prices = {for (final c in items) c.id: cheapestUnitPrice(c)};
        items.sort(
          (a, b) => byNullable(
            prices[a.id],
            prices[b.id],
            desc: sort == ComponentSort.priceDesc,
          ),
        );
      case ComponentSort.stockAsc:
        items.sort((a, b) => byNullable(a.stockTotal, b.stockTotal));
    }
  }

  Stream<Component?> watchOne(int id) {
    final queryBuilder = _componentBox.query(Component_.id.equals(id));
    return queryBuilder
        .watch(triggerImmediately: true)
        .map((query) => query.findFirst());
  }

  Future<int> add(Component component) async {
    final existingComponent = _componentBox
        .query(Component_.name.equals(component.name))
        .findFirstAndClose();

    if (existingComponent != null) {
      throw EntityAlreadyExistsException(
        "Component với tên '${component.name}' đã tồn tại.",
      );
    }
    component.id = 0;
    return _componentBox.put(component);
  }

  Future<int> update(Component component) async {
    final existingComponent = _componentBox.get(component.id);
    if (existingComponent == null) {
      throw EntityNotFoundException(
        "Không tìm thấy Component với id ${component.id}",
      );
    }

    final duplicateComponent = _componentBox
        .query(
          Component_.name.equals(component.name) &
              Component_.id.notEquals(component.id),
        )
        .findFirstAndClose();
    if (duplicateComponent != null) {
      throw EntityAlreadyExistsException(
        "Component với tên '${component.name}' đã tồn tại.",
      );
    }

    return _db.store.runInTransaction(TxMode.write, () {
      final id = _componentBox.put(component);
      _syncVariants(component);
      return id;
    });
  }

  /// Khi thuộc tính biến thể đổi: bỏ các giá trị không còn tồn tại khỏi phạm
  /// vi áp dụng của tuỳ chọn và gộp lại tồn kho theo biến thể mới.
  void _syncVariants(Component component) {
    final attributes = component.attributes;

    final optionBox = _db.get<ComponentOption>();
    final options = optionBox
        .query(ComponentOption_.component.equals(component.id))
        .findAndClose();
    for (final option in options) {
      option.availability = Variants.sanitizeAvailability(
        option.availability,
        attributes,
      );
    }
    optionBox.putMany(options);

    final stockBox = _db.get<StockItem>();
    final stocks = stockBox
        .query(StockItem_.component.equals(component.id))
        .findAndClose();
    final merged = <String, StockItem>{};
    final removed = <int>[];
    for (final stock in stocks) {
      stock.variant = Variants.sanitizeSelection(stock.variant, attributes);
      final key = Variants.key(stock.variant);
      final existing = merged[key];
      if (existing == null) {
        merged[key] = stock;
      } else {
        existing.quantity += stock.quantity;
        if (existing.location.isEmpty) existing.location = stock.location;
        removed.add(stock.id);
      }
    }
    stockBox.putMany(merged.values.toList());
    stockBox.removeMany(removed);
  }

  /// Nhân bản linh kiện kèm toàn bộ tuỳ chọn (không kèm tồn kho). Trả về id bản sao.
  Future<int> clone(int id) async {
    final source = _componentBox.get(id);
    if (source == null) {
      throw EntityNotFoundException("Không tìm thấy Component với id $id");
    }

    return _db.store.runInTransaction(TxMode.write, () {
      final copy = Component(
        name: nextCopyName(
          source.name,
          (name) =>
              _componentBox
                  .query(Component_.name.equals(name))
                  .findFirstAndClose() !=
              null,
        ),
        description: source.description,
        base64Image: source.base64Image,
        iconSvg: source.iconSvg,
        attributesJson: source.attributesJson,
        lowStockThreshold: source.lowStockThreshold,
      );
      copy.category.targetId = source.category.targetId;
      copy.type.targetId = source.type.targetId;
      final newId = _componentBox.put(copy);

      final now = DateTime.now();
      for (final option in source.options) {
        final optionCopy = ComponentOption(
          name: option.name,
          unitsPerPack: option.unitsPerPack,
          pricePerPack: option.pricePerPack,
          link: option.link,
          shop: option.shop,
          availabilityJson: option.availabilityJson,
          priceCheckedAt: option.priceCheckedAt ?? now,
        )..component.targetId = newId;
        final optionId = _db.get<ComponentOption>().put(optionCopy);
        _db.get<PriceRecord>().put(
          PriceRecord(
            pricePerPack: option.pricePerPack,
            unitsPerPack: option.unitsPerPack,
            recordedAt: option.priceCheckedAt ?? now,
          )..option.targetId = optionId,
        );
      }
      return newId;
    });
  }

  /// Xoá linh kiện kèm tuỳ chọn, lịch sử giá và tồn kho của nó.
  Future<bool> delete(int id) async {
    final existingComponent = _componentBox.get(id);
    if (existingComponent == null) {
      throw EntityNotFoundException("Không tìm thấy Component với id $id");
    }
    return _db.store.runInTransaction(TxMode.write, () {
      final optionIds = _db
          .get<ComponentOption>()
          .query(ComponentOption_.component.equals(id))
          .getIdsAndClose();
      _db.get<PriceRecord>().query(PriceRecord_.option.anyOf(optionIds)).build()
        ..remove()
        ..close();
      _db.get<ComponentOption>().removeMany(optionIds);
      _db.get<StockItem>().query(StockItem_.component.equals(id)).build()
        ..remove()
        ..close();
      return _componentBox.remove(id);
    });
  }
}
