import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/search_params/component_search_params.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'component_notifier.g.dart';

@riverpod
class ComponentNotifier extends _$ComponentNotifier {
  @override
  void build() {}

  Future<int> addComponent(Component component) async {
    final componentRepository = ref.read(componentRepositoryProvider);
    return await componentRepository.add(component);
  }

  Future<int> updateComponent(Component component) async {
    final componentRepository = ref.read(componentRepositoryProvider);
    return await componentRepository.update(component);
  }

  Future<bool> deleteComponent(int id) async {
    final componentRepository = ref.read(componentRepositoryProvider);
    return await componentRepository.delete(id);
  }
}

@riverpod
Stream<PageResult<Component>> watchComponents(
  Ref ref,
  ComponentSearchParams searchParams,
) {
  final componentRepository = ref.watch(componentRepositoryProvider);
  return componentRepository.watchPaged(searchParams);
}

@riverpod
Stream<Map<Category, List<Component>>> watchAllComponentsGroupedByCategory(
  Ref ref,
  ComponentSearchParams searchParams,
) {
  final componentRepository = ref.watch(componentRepositoryProvider);
  return componentRepository.watchAll(searchParams).map((components) {
    final Map<Category, List<Component>> grouped = {};
    for (var component in components) {
      final category = component.category.target;
      if (category != null) {
        grouped.putIfAbsent(category, () => []).add(component);
      }
    }
    return grouped;
  });
}
