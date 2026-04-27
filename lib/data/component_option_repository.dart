import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/search_params/component_option_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'component_option_repository.g.dart';

@riverpod
ComponentOptionRepository componentOptionRepository(Ref ref) =>
    ComponentOptionRepository();

class ComponentOptionRepository {
  final _componentOptionBox = ObjectboxService.instance.get<ComponentOption>();

  Stream<List<ComponentOption>> watchAll() {
    return _componentOptionBox.query().watchQuery();
  }

  Stream<List<ComponentOption>> watchPaged(
    ComponentOptionSearchParams searchParams,
  ) {
    Condition<ComponentOption>? condition;
    condition = condition
        .safeAnd(searchParams.componentId, ComponentOption_.component.equals)
        .safeAnd(
          searchParams.name,
          (name) => ComponentOption_.name.contains(name, caseSensitive: false),
        );

    final queryBuilder = _componentOptionBox.query(condition);
    return queryBuilder.watchQuery();
  }

  Future<void> add(ComponentOption componentOption) async {
    Condition<ComponentOption>? duplicateCondition;
    duplicateCondition = duplicateCondition
        .safeAnd(componentOption.name, ComponentOption_.name.equals)
        .safeAnd(
          componentOption.component.target?.id,
          ComponentOption_.component.equals,
        );

    final duplicateComponentOption = _componentOptionBox
        .query(duplicateCondition)
        .build()
        .findFirst();

    if (duplicateComponentOption != null) {
      throw EntityAlreadyExistsException(
        "ComponentOption với tên ${componentOption.name} đã tồn tại",
      );
    }
    componentOption.id = 0;
    await _componentOptionBox.putAsync(componentOption);
  }

  Future<void> update(ComponentOption componentOption) async {
    final existingOption = _componentOptionBox.get(componentOption.id);
    if (existingOption == null) {
      throw EntityNotFoundException(
        "Không tìm thấy ComponentOption với id ${componentOption.id}",
      );
    }

    Condition<ComponentOption>? duplicateCondition;
    duplicateCondition = duplicateCondition
        .safeAnd(componentOption.name, ComponentOption_.name.equals)
        .safeAnd(componentOption.id, ComponentOption_.id.notEquals)
        .safeAnd(
          componentOption.component.target?.id,
          ComponentOption_.component.equals,
        );

    final duplicateOption = _componentOptionBox
        .query(duplicateCondition)
        .build()
        .findFirst();
    if (duplicateOption != null) {
      throw EntityAlreadyExistsException(
        "ComponentOption với tên ${componentOption.name} đã tồn tại",
      );
    }

    await _componentOptionBox.putAsync(componentOption);
  }

  Future<void> delete(int id) async {
    final option = _componentOptionBox.get(id);
    if (option == null) {
      throw EntityNotFoundException(
        "Không tìm thấy ComponentOption với id $id",
      );
    }
    await _componentOptionBox.removeAsync(id);
  }
}
