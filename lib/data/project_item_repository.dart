import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/util/purchase_planner.dart';
import 'package:component_companion/model/search_params/project_item_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_item_repository.g.dart';

@riverpod
ProjectItemRepository projectItemRepository(Ref ref) => ProjectItemRepository();

/// Số lượng cũ của dòng được giữ (id => số lượng) + các dòng đã bị gộp.
typedef ProjectMergeUndo = ({
  Map<int, int> quantities,
  List<ProjectItem> removed,
});

class ProjectItemRepository {
  final _db = ObjectboxService.instance;
  final _projectItemBox = ObjectboxService.instance.get<ProjectItem>();

  Stream<List<ProjectItem>> watchAll(ProjectItemSearchParams searchParams) {
    Condition<ProjectItem>? condition;
    condition = condition
        .safeAnd(searchParams.projectId, ProjectItem_.project.equals)
        .safeAnd(
          searchParams.projectOptionId,
          ProjectItem_.projectOption.equals,
        );

    // Item hiển thị tên/ảnh linh kiện, giá tuỳ chọn, icon loại và màu danh mục
    // => lắng nghe cả các bảng liên quan
    return _db
        .watchTables([
          _db.store.watch<ProjectItem>(),
          _db.store.watch<Component>(),
          _db.store.watch<ComponentOption>(),
          _db.store.watch<ComponentType>(),
          _db.store.watch<Category>(),
          _db.store.watch<ComponentVariant>(),
          _db.store.watch<Shop>(),
        ])
        .map((_) => _projectItemBox.query(condition).findAndClose());
  }

  Future<int> add(ProjectItem projectItem) async {
    projectItem.id = 0;
    return _projectItemBox.put(projectItem);
  }

  /// Thêm nhiều linh kiện 1 lần (VD dán BOM). Trả về số dòng đã thêm.
  Future<int> addMany(List<ProjectItem> items) async {
    for (final item in items) {
      item.id = 0;
    }
    return _projectItemBox.putMany(items).length;
  }

  Future<int> update(ProjectItem projectItem) async {
    final existProjectItem = _projectItemBox
        .query(ProjectItem_.id.equals(projectItem.id))
        .build()
        .findFirst();

    if (existProjectItem == null) {
      throw EntityNotFoundException(
        "ProjectItem với id ${projectItem.id} không tồn tại!",
      );
    }

    return _projectItemBox.put(projectItem);
  }

  Future<bool> delete(int id) async {
    final existProjectItem = _projectItemBox
        .query(ProjectItem_.id.equals(id))
        .build()
        .findFirst();

    if (existProjectItem == null) {
      throw EntityNotFoundException("ProjectItem với id $id không tồn tại!");
    }

    return _projectItemBox.remove(id);
  }

  /// Mọi linh kiện của dự án (phần cơ bản + mọi phiên bản).
  List<ProjectItem> allOfProject(int projectId) {
    final optionIds = _db
        .get<ProjectOption>()
        .query(ProjectOption_.project.equals(projectId))
        .getIdsAndClose();
    return _projectItemBox
        .query(
          optionIds.isEmpty
              ? ProjectItem_.project.equals(projectId)
              : ProjectItem_.project.equals(projectId) |
                    ProjectItem_.projectOption.anyOf(optionIds),
        )
        .findAndClose();
  }

  /// Dự án chứa [item] (dòng của phương án => dự án của phương án).
  int projectIdOf(ProjectItem item) {
    if (item.project.targetId != 0) return item.project.targetId;
    final optionId = item.projectOption.targetId;
    if (optionId == 0) return 0;
    final option = _db.get<ProjectOption>().get(optionId);
    if (option == null) return 0;
    // Phương án cũ có thể chỉ gắn nhóm
    return option.project.targetId != 0
        ? option.project.targetId
        : option.group.target?.project.targetId ?? 0;
  }

  /// Thêm [items]; dòng có chỉ số trong [mergeInto] (chỉ số => id dòng có
  /// sẵn) được cộng số lượng vào dòng đó thay vì thêm mới.
  Future<({int added, int merged})> addOrMerge(
    List<ProjectItem> items, {
    Map<int, int> mergeInto = const {},
  }) async {
    return _db.store.runInTransaction(TxMode.write, () {
      final targets = <int, ProjectItem>{};
      final fresh = <ProjectItem>[];
      for (var i = 0; i < items.length; i++) {
        final targetId = mergeInto[i];
        final target = targetId == null
            ? null
            : targets[targetId] ??= _projectItemBox.get(targetId)!;
        if (target == null) {
          fresh.add(items[i]..id = 0);
        } else {
          target.quantity += items[i].quantity;
        }
      }
      _projectItemBox.putMany([...fresh, ...targets.values]);
      return (added: fresh.length, merged: items.length - fresh.length);
    });
  }

  /// Gộp mỗi nhóm dòng trùng vào dòng đầu (cộng số lượng, giữ tuỳ chọn mua
  /// của dòng đầu), xoá các dòng còn lại. Trả về dữ liệu để [undoMerge].
  Future<ProjectMergeUndo> mergeDuplicates(
    List<List<ProjectItem>> groups,
  ) async {
    return _db.store.runInTransaction(TxMode.write, () {
      final quantities = <int, int>{};
      final removed = <ProjectItem>[];
      for (final group in groups) {
        final kept = _projectItemBox.get(group.first.id);
        if (kept == null) continue;
        quantities[kept.id] = kept.quantity;
        for (final other in group.skip(1)) {
          final item = _projectItemBox.get(other.id);
          if (item == null) continue;
          kept.quantity += item.quantity;
          removed.add(item);
        }
        _projectItemBox.put(kept);
      }
      _projectItemBox.removeMany([for (final r in removed) r.id]);
      return (quantities: quantities, removed: removed);
    });
  }

  /// Trả lại số lượng cũ và thêm lại các dòng đã bị gộp (id mới).
  Future<void> undoMerge(ProjectMergeUndo undo) async {
    _db.store.runInTransaction(TxMode.write, () {
      final kept = _projectItemBox
          .getMany(undo.quantities.keys.toList())
          .whereType<ProjectItem>()
          .toList();
      for (final item in kept) {
        item.quantity = undo.quantities[item.id]!;
      }
      _projectItemBox.putMany([
        ...kept,
        for (final r in undo.removed) r..id = 0,
      ]);
    });
  }

  /// Đổi mọi linh kiện của dự án sang tuỳ chọn mua rẻ nhất cho đúng số lượng
  /// cần (theo biến thể). Trả về số linh kiện đã đổi, số tiền tiết kiệm và
  /// tuỳ chọn cũ của từng linh kiện (để hoàn tác bằng [restoreOptions]).
  Future<({int switched, double saving, Map<int, int> previous})> useCheapest(
    int projectId,
  ) async {
    final previous = <int, int>{};
    final changed = <ProjectItem>[];
    var saving = 0.0;
    for (final item in allOfProject(projectId)) {
      final cheaper = PurchasePlanner.cheaperFor(item);
      if (cheaper == null) continue;
      final current = item.componentOption.target;
      final variantId = item.variant.targetId;
      int cost(ComponentOption o) =>
          PurchasePlanner.singleCost(o, item.quantity, variantId: variantId);
      final before = current == null ? cost(cheaper) : cost(current);
      saving += before - cost(cheaper);
      previous[item.id] = item.componentOption.targetId;
      item.componentOption.targetId = cheaper.id;
      changed.add(item);
    }
    _projectItemBox.putMany(changed);
    return (switched: changed.length, saving: saving, previous: previous);
  }

  /// Đặt lại tuỳ chọn mua của các linh kiện (itemId -> optionId).
  Future<void> restoreOptions(Map<int, int> options) async {
    final items = _projectItemBox
        .getMany(options.keys.toList())
        .whereType<ProjectItem>()
        .toList();
    for (final item in items) {
      item.componentOption.targetId = options[item.id]!;
    }
    _projectItemBox.putMany(items);
  }
}
