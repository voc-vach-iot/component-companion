import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/shop.dart';
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
        _db.store.watch<ComponentVariant>(),
        _db.store.watch<ComponentOption>(),
        _db.store.watch<Shop>(),
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
      // Có ít nhất 1 biến thể hết / sắp hết
      StockFilter.out => c.outCount > 0,
      StockFilter.low => c.lowCount > 0 || c.outCount > 0,
      StockFilter.inStock => total != null && total > 0,
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

  /// 1 linh kiện kèm biến thể, tuỳ chọn mua, shop, lịch sử giá (trang chi tiết).
  Stream<Component?> watchOne(int id) => _db
      .watchTables([
        _db.store.watch<Component>(),
        _db.store.watch<Category>(),
        _db.store.watch<ComponentType>(),
        _db.store.watch<ComponentVariant>(),
        _db.store.watch<ComponentOption>(),
        _db.store.watch<Shop>(),
        _db.store.watch<PriceRecord>(),
      ])
      .map((_) => _componentBox.get(id));

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
    return _db.store.runInTransaction(TxMode.write, () {
      final id = _componentBox.put(component);
      // Linh kiện không có thuộc tính => 1 biến thể mặc định để quản lý kho / giá
      if (component.attributes.isEmpty) {
        _db.get<ComponentVariant>().put(
          ComponentVariant()..component.targetId = id,
        );
      }
      return id;
    });
  }

  /// Cập nhật linh kiện. [renames] = các thuộc tính / giá trị được đổi tên
  /// trong lần sửa này, để biến thể đang dùng tên cũ đi theo tên mới.
  Future<int> update(
    Component component, {
    AttributeRenames renames = AttributeRenames.none,
  }) async {
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
      if (!renames.isEmpty) _renameVariants(component.id, renames);
      _syncVariants(component);
      return id;
    });
  }

  void _renameVariants(int componentId, AttributeRenames renames) {
    final variantBox = _db.get<ComponentVariant>();
    final variants = variantBox
        .query(ComponentVariant_.component.equals(componentId))
        .findAndClose();
    for (final v in variants) {
      v.selection = Variants.applyRenames(v.selection, renames);
    }
    variantBox.putMany(variants);
  }

  /// Khi thuộc tính đổi: chuẩn hoá biến thể theo thuộc tính mới và gộp các
  /// biến thể bị trùng (cộng tồn kho, gộp tuỳ chọn mua, trỏ lại dự án).
  void _syncVariants(Component component) {
    final attributes = component.attributes;
    final variantBox = _db.get<ComponentVariant>();
    final variants = variantBox
        .query(ComponentVariant_.component.equals(component.id))
        .findAndClose();

    if (variants.isEmpty) {
      if (attributes.isEmpty) {
        variantBox.put(ComponentVariant()..component.targetId = component.id);
      }
      return;
    }

    final groups = <String, List<ComponentVariant>>{};
    for (final v in variants) {
      // Thuộc tính mới thêm / giá trị bị xoá => tạm gán giá trị đầu tiên để
      // biến thể luôn đủ thông số (người dùng sửa lại sau nếu cần)
      final current = v.selection;
      v.selection = {
        for (final a in attributes)
          a.name: a.values.contains(current[a.name])
              ? current[a.name]!
              : a.values.first,
      };
      groups.putIfAbsent(Variants.key(v.selection), () => []).add(v);
    }
    for (final group in groups.values) {
      _mergeVariants(group.first, group.skip(1).toList());
    }
  }

  /// Gộp [others] vào [keeper] rồi xoá [others].
  void _mergeVariants(ComponentVariant keeper, List<ComponentVariant> others) {
    final variantBox = _db.get<ComponentVariant>();
    if (others.isEmpty) {
      variantBox.put(keeper);
      return;
    }
    final optionBox = _db.get<ComponentOption>();
    final itemBox = _db.get<ProjectItem>();
    for (final other in others) {
      if (other.stock != null) {
        keeper.stock = (keeper.stock ?? 0) + other.stock!;
      }
      if (keeper.location.isEmpty) keeper.location = other.location;

      final options = other.options.toList();
      for (final o in options) {
        o.variants.removeWhere((v) => v.id == other.id);
        if (!o.variants.any((v) => v.id == keeper.id)) o.variants.add(keeper);
      }
      optionBox.putMany(options);

      final items = other.projectItems.toList();
      for (final i in items) {
        i.variant.target = keeper;
      }
      itemBox.putMany(items);
    }
    variantBox.put(keeper);
    variantBox.removeMany(others.map((v) => v.id).toList());
  }

  /// Nhân bản linh kiện kèm biến thể và tuỳ chọn mua (không kèm tồn kho).
  /// Trả về id bản sao.
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

      final variantBox = _db.get<ComponentVariant>();
      final variantMap = <int, ComponentVariant>{};
      for (final v in source.variants) {
        final vCopy = ComponentVariant(
          selectionJson: v.selectionJson,
          location: v.location,
          lowStockThreshold: v.lowStockThreshold,
          note: v.note,
        )..component.targetId = newId;
        variantBox.put(vCopy);
        variantMap[v.id] = vCopy;
      }

      final now = DateTime.now();
      for (final option in source.options) {
        final optionCopy =
            ComponentOption(
                name: option.name,
                unitsPerPack: option.unitsPerPack,
                pricePerPack: option.pricePerPack,
                link: option.link,
                priceCheckedAt: option.priceCheckedAt ?? now,
              )
              ..component.targetId = newId
              ..shop.targetId = option.shop.targetId;
        optionCopy.variants.addAll(
          option.variants
              .map((v) => variantMap[v.id])
              .whereType<ComponentVariant>(),
        );
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
      _db
          .get<ComponentVariant>()
          .query(ComponentVariant_.component.equals(id))
          .build()
        ..remove()
        ..close();
      _db.get<StockItem>().query(StockItem_.component.equals(id)).build()
        ..remove()
        ..close();
      return _componentBox.remove(id);
    });
  }
}
