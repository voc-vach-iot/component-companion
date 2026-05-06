import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/extension/objectbox/query_string_property.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/search_params/project_option_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_option_repository.g.dart';

@riverpod
ProjectOptionRepository projectOptionRepository(Ref ref) =>
    ProjectOptionRepository();

class ProjectOptionRepository {
  final _projectOptionBox = ObjectboxService.instance.get<ProjectOption>();

  Stream<List<ProjectOption>> watchAll(ProjectOptionSearchParams searchParams) {
    Condition<ProjectOption>? condition;
    condition = condition
        .safeAnd(searchParams.projectId, ProjectOption_.project.equals)
        .safeAnd(searchParams.name, ProjectOption_.name.containsIgnorecase);
    final queryBuilder = _projectOptionBox.query(condition);

    return queryBuilder.watchQuery();
  }

  Future<int> add(ProjectOption projectOption) async {
    Condition<ProjectOption>? duplicateCondition;

    duplicateCondition = duplicateCondition
        .safeAnd(projectOption.name, ProjectOption_.name.equals)
        .safeAnd(
          projectOption.project.target?.id,
          ProjectOption_.project.equals,
        );

    final existingProjectOption = _projectOptionBox
        .query(duplicateCondition)
        .build()
        .findFirst();

    if (existingProjectOption != null) {
      throw EntityAlreadyExistsException(
        "ProjectOption với tên '${projectOption.name}' đã tồn tại",
      );
    }

    projectOption.id = 0;
    return _projectOptionBox.put(projectOption);
  }

  Future<int> update(ProjectOption projectOption) async {
    final existingProjectOption = _projectOptionBox
        .query(ProjectOption_.id.equals(projectOption.id))
        .build()
        .findFirst();

    if (existingProjectOption == null) {
      throw EntityNotFoundException(
        "ProjectOption với id ${projectOption.id} không tồn tại!",
      );
    }

    Condition<ProjectOption>? duplicateCondition;
    duplicateCondition = duplicateCondition
        .safeAnd(projectOption.name, ProjectOption_.name.equals)
        .safeAnd(
          projectOption.project.target?.id,
          ProjectOption_.project.equals,
        )
        .safeAnd(projectOption.id, ProjectOption_.id.notEquals);

    final duplicateProjectOption = _projectOptionBox
        .query(duplicateCondition)
        .build()
        .findFirst();

    if (duplicateProjectOption != null) {
      throw EntityAlreadyExistsException(
        "ProjectOption với tên '${projectOption.name}' đã tồn tại",
      );
    }

    return _projectOptionBox.put(projectOption);
  }

  Future<bool> delete(int id) async {
    final existingProjectOption = _projectOptionBox
        .query(ProjectOption_.id.equals(id))
        .build()
        .findFirst();

    if (existingProjectOption == null) {
      throw EntityNotFoundException("ProjectOption với id $id không tồn tại!");
    }

    return _projectOptionBox.remove(id);
  }
}
