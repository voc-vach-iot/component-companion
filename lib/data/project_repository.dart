import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/search_params/project_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_repository.g.dart';

@riverpod
ProjectRepository projectRepository(Ref ref) => ProjectRepository();

class ProjectRepository {
  final _db = ObjectboxService.instance;
  final _projectBox = ObjectboxService.instance.get<Project>();

  Stream<PageResult<Project>> watchPaged(ProjectSearchParams searchParams) {
    // Lọc tên trong Dart vì cần bỏ dấu / khớp nhiều từ mà ObjectBox không hỗ trợ
    final search = TextSearch(searchParams.name, searchParams.searchOptions);

    // Card dự án hiển thị số phiên bản => lắng nghe cả bảng ProjectOption
    return _db
        .watchTables([
          _db.store.watch<Project>(),
          _db.store.watch<ProjectOption>(),
        ])
        .map(
          (_) => search
              .filter(_projectBox.query().findAndClose(), (p) => p.name)
              .toPage(
                page: searchParams.page,
                size: searchParams.size,
                focusId: searchParams.focusId,
                idOf: (p) => p.id,
              ),
        );
  }

  /// Mọi dự án kèm phiên bản + linh kiện (cho danh sách cần mua / tổng quan).
  Stream<List<Project>> watchAllWithItems() => _db
      .watchTables([
        _db.store.watch<Project>(),
        _db.store.watch<ProjectOption>(),
        _db.store.watch<ProjectItem>(),
        _db.store.watch<Component>(),
        _db.store.watch<ComponentOption>(),
        _db.store.watch<StockItem>(),
      ])
      .map(
        (_) =>
            _projectBox.getAll()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      );

  Stream<Project?> watchById(int id) {
    return _projectBox.query(Project_.id.equals(id)).watchSingle();
  }

  Future<int> add(Project project) async {
    Condition<Project>? duplicateCondition;
    duplicateCondition = duplicateCondition.safeAnd(
      project.name,
      Project_.name.equals,
    );

    final existingProject = _projectBox
        .query(duplicateCondition)
        .build()
        .findFirst();

    if (existingProject != null) {
      throw EntityAlreadyExistsException(
        "Project với tên ${project.name} đã tồn tại",
      );
    }

    project.id = 0;
    return await _projectBox.putAsync(project);
  }

  Future<int> update(Project project) async {
    final existingProject = _projectBox
        .query(Project_.id.equals(project.id))
        .build()
        .findFirst();

    if (existingProject == null) {
      throw EntityNotFoundException(
        "Project với id ${project.id} không tồn tại!",
      );
    }

    Condition<Project>? duplicateCondition;
    duplicateCondition = duplicateCondition
        .safeAnd(project.name, Project_.name.equals)
        .safeAnd(project.id, Project_.id.notEquals);

    final duplicateProject = _projectBox
        .query(duplicateCondition)
        .build()
        .findFirst();
    if (duplicateProject != null) {
      throw EntityAlreadyExistsException(
        "Project với tên ${project.name} đã tồn tại",
      );
    }

    return await _projectBox.putAsync(project);
  }

  Future<bool> delete(int id) async {
    final existingProject = _projectBox
        .query(Project_.id.equals(id))
        .build()
        .findFirst();

    if (existingProject == null) {
      throw EntityNotFoundException("Project với id $id không tồn tại!");
    }

    // Xoá kèm phiên bản và linh kiện trong dự án
    return _db.store.runInTransaction(TxMode.write, () {
      final optionIds = _db
          .get<ProjectOption>()
          .query(ProjectOption_.project.equals(id))
          .getIdsAndClose();
      _db
          .get<ProjectItem>()
          .query(
            optionIds.isEmpty
                ? ProjectItem_.project.equals(id)
                : ProjectItem_.project.equals(id) |
                      ProjectItem_.projectOption.anyOf(optionIds),
          )
          .build()
        ..remove()
        ..close();
      _db.get<ProjectOption>().removeMany(optionIds);
      return _projectBox.remove(id);
    });
  }
}
