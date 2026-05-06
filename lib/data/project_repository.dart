import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/extension/objectbox/query_string_property.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/search_params/project_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_repository.g.dart';

@riverpod
ProjectRepository projectRepository(Ref ref) => ProjectRepository();

class ProjectRepository {
  final _projectBox = ObjectboxService.instance.get<Project>();

  Stream<PageResult<Project>> watchPaged(ProjectSearchParams searchParams) {
    Condition<Project>? condition;
    condition = condition.safeAnd(
      searchParams.name,
      Project_.name.containsIgnorecase,
    );

    return _projectBox
        .query(condition)
        .watchPage(page: searchParams.page, size: searchParams.size);
  }

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

    return await _projectBox.removeAsync(id);
  }
}
