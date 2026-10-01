import 'package:component_companion/data/component_type_repository.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/search_params/component_type_search_params.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'component_type_notifier.g.dart';

@riverpod
class ComponentTypeNotifier extends _$ComponentTypeNotifier {
  @override
  void build() {}

  Future<int> addComponentType(ComponentType type) async {
    final repository = ref.read(componentTypeRepositoryProvider);
    return await repository.add(type);
  }

  Future<int> updateComponentType(ComponentType type) async {
    final repository = ref.read(componentTypeRepositoryProvider);
    return await repository.update(type);
  }

  Future<bool> deleteComponentType(int id) async {
    final repository = ref.read(componentTypeRepositoryProvider);
    return await repository.delete(id);
  }
}

@riverpod
Stream<List<ComponentType>> watchAllComponentTypes(
  Ref ref, {
  ComponentTypeSearchParams? searchParams,
}) {
  final repository = ref.watch(componentTypeRepositoryProvider);
  return repository.watchAll(searchParams);
}

@riverpod
Stream<PageResult<ComponentType>> watchComponentTypes(
  Ref ref,
  ComponentTypeSearchParams searchParams,
) {
  final repository = ref.watch(componentTypeRepositoryProvider);
  return repository.watchPaged(searchParams);
}
