import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/search_params/component_option_search_params.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part "component_option_notifier.g.dart";

@riverpod
class ComponentOptionNotifier extends _$ComponentOptionNotifier {
  @override
  void build() {}

  Future<void> addComponentOption(ComponentOption componentOption) async {
    final componentOptionRepository = ref.read(
      componentOptionRepositoryProvider,
    );
    await componentOptionRepository.add(componentOption);
  }

  Future<void> updateComponentOption(ComponentOption componentOption) async {
    final componentOptionRepository = ref.read(
      componentOptionRepositoryProvider,
    );
    await componentOptionRepository.update(componentOption);
  }

  Future<void> deleteComponentOption(int id) async {
    final componentOptionRepository = ref.read(
      componentOptionRepositoryProvider,
    );
    await componentOptionRepository.delete(id);
  }
}

@riverpod
Stream<List<ComponentOption>> watchComponentOptions(
  Ref ref,
  ComponentOptionSearchParams searchParams,
) {
  final componentOptionRepository = ref.watch(
    componentOptionRepositoryProvider,
  );
  return componentOptionRepository.watchAll(searchParams);
}
