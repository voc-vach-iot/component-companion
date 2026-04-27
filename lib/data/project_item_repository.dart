import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/search_params/project_item_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_item_repository.g.dart';

@riverpod
ProjectItemRepository projectItemRepository(Ref ref) => ProjectItemRepository();

class ProjectItemRepository {
  final _projectItemBox = ObjectboxService.instance.get<ProjectItem>();

  Stream<List<ProjectItem>> watchAll(ProjectItemSearchParams searchParams) {
    Condition<ProjectItem>? condition;
    condition = condition
        .safeAnd(searchParams.projectId, ProjectItem_.project.equals)
        .safeAnd(
          searchParams.projectOptionId,
          ProjectItem_.projectOption.equals,
        );

    final queryBuilder = _projectItemBox.query(condition);

    return queryBuilder.watchQuery();
  }

  Future<void> add(ProjectItem projectItem) async {
    projectItem.id = 0;
    _projectItemBox.put(projectItem);
  }

  Future<void> update(ProjectItem projectItem) async {
    final existProjectItem = _projectItemBox
        .query(ProjectItem_.id.equals(projectItem.id))
        .build()
        .findFirst();

    if (existProjectItem == null) {
      throw EntityNotFoundException(
        "ProjectItem với id ${projectItem.id} không tồn tại!",
      );
    }

    _projectItemBox.put(projectItem);
  }

  Future<void> delete(int id) async {
    final existProjectItem = _projectItemBox
        .query(ProjectItem_.id.equals(id))
        .build()
        .findFirst();

    if (existProjectItem == null) {
      throw EntityNotFoundException("ProjectItem với id $id không tồn tại!");
    }

    _projectItemBox.remove(id);
  }
}
