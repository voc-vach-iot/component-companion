import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/search_params/component_option_search_params.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part "component_option_notifier.g.dart";

@riverpod
class ComponentOptionNotifier extends _$ComponentOptionNotifier {
  @override
  void build() {}

  Future<int> addComponentOption(ComponentOption componentOption) async {
    final componentOptionRepository = ref.read(
      componentOptionRepositoryProvider,
    );
    final id = await componentOptionRepository.add(componentOption);
    if (ref.mounted) {
      ref.read(componentOptionEventProvider.notifier).notify();
    }
    return id;
  }

  Future<int> updateComponentOption(ComponentOption componentOption) async {
    final componentOptionRepository = ref.read(
      componentOptionRepositoryProvider,
    );
    final id = await componentOptionRepository.update(componentOption);
    if (ref.mounted) {
      ref.read(componentOptionEventProvider.notifier).notify();
    }
    return id;
  }

  Future<bool> deleteComponentOption(int id) async {
    final componentOptionRepository = ref.read(
      componentOptionRepositoryProvider,
    );
    final success = await componentOptionRepository.delete(id);
    if (ref.mounted && success) {
      ref.read(componentOptionEventProvider.notifier).notify();
    }
    return success;
  }
}

@riverpod
class ComponentOptionEventNotifier extends _$ComponentOptionEventNotifier {
  @override
  int build() => 0;

  void notify() => state++;
}

@riverpod
Stream<List<ComponentOption>> watchAllComponentOptions(
  Ref ref,
  ComponentOptionSearchParams searchParams,
) {
  final componentOptionRepository = ref.watch(
    componentOptionRepositoryProvider,
  );
  return componentOptionRepository.watchAll(searchParams);
}
