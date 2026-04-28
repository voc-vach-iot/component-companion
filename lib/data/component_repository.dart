import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/extension/objectbox/query_string_property.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/search_params/component_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'component_repository.g.dart';

@riverpod
ComponentRepository componentRepository(Ref ref) => ComponentRepository();

class ComponentRepository {
  final _componentBox = ObjectboxService.instance.get<Component>();

  Stream<List<Component>> watchAll(ComponentSearchParams searchParams) {
    Condition<Component>? condition;
    condition = condition.safeAnd(
      searchParams.name,
      Component_.name.containsIgnorecase,
    );

    final queryBuilder = _componentBox.query(condition);

    return queryBuilder.watchQuery();
  }

  Stream<PageResult<Component>> watchPaged(ComponentSearchParams searchParams) {
    Condition<Component>? condition;
    condition = condition.safeAnd(
      searchParams.name,
      Component_.name.containsIgnorecase,
    );
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

    return queryBuilder.watchPage(
      page: searchParams.page,
      size: searchParams.size,
    );
  }

  Future<int> add(Component component) async {
    Condition<Component>? duplicateCondition;

    duplicateCondition = duplicateCondition.safeAnd(
      component.name,
      Component_.name.equals,
    );

    final existingComponent = _componentBox
        .query(duplicateCondition)
        .build()
        .findFirst();

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

    Condition<Component>? duplicateCondition;
    duplicateCondition = duplicateCondition
        .safeAnd(component.name, Component_.name.equals)
        .safeAnd(component.id, Component_.id.notEquals);
    final duplicateComponent = _componentBox
        .query(duplicateCondition)
        .build()
        .findFirst();
    if (duplicateComponent != null) {
      throw EntityAlreadyExistsException(
        "Component với tên '${component.name}' đã tồn tại.",
      );
    }
    return _componentBox.put(component);
  }

  Future<bool> delete(int id) async {
    final existingComponent = _componentBox.get(id);
    if (existingComponent == null) {
      throw EntityNotFoundException("Không tìm thấy Component với id $id");
    }
    return _componentBox.remove(id);
  }
}
