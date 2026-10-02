import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/util/price_advisor.dart';
import 'package:component_companion/model/search_params/project_item_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_item_repository.g.dart';

@riverpod
ProjectItemRepository projectItemRepository(Ref ref) => ProjectItemRepository();

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
          _db.store.watch<StockItem>(),
        ])
        .map((_) => _projectItemBox.query(condition).findAndClose());
  }

  Future<int> add(ProjectItem projectItem) async {
    projectItem.id = 0;
    return _projectItemBox.put(projectItem);
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

  /// Đổi mọi linh kiện của dự án sang tuỳ chọn rẻ nhất phù hợp biến thể.
  /// Trả về số linh kiện đã đổi và số tiền tiết kiệm.
  Future<({int switched, double saving})> useCheapest(int projectId) async {
    final changed = <ProjectItem>[];
    var saving = 0.0;
    for (final item in allOfProject(projectId)) {
      final cheaper = PriceAdvisor.cheaperFor(item);
      if (cheaper == null) continue;
      final current = item.componentOption.target;
      saving +=
          ((current?.pricePerUnit ?? cheaper.pricePerUnit) -
              cheaper.pricePerUnit) *
          item.quantity;
      item.componentOption.targetId = cheaper.id;
      changed.add(item);
    }
    _projectItemBox.putMany(changed);
    return (switched: changed.length, saving: saving);
  }
}
