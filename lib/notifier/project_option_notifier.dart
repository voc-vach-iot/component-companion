import 'package:component_companion/data/project_option_repository.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/search_params/project_option_search_params.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_option_notifier.g.dart';

@riverpod
class ProjectOptionNotifier extends _$ProjectOptionNotifier {
  @override
  void build() {}

  Future<int> addProjectOption(ProjectOption projectOption) async {
    final repository = ref.read(projectOptionRepositoryProvider);
    return await repository.add(projectOption);
  }

  Future<int> updateProjectOption(ProjectOption projectOption) async {
    final repository = ref.read(projectOptionRepositoryProvider);
    return await repository.update(projectOption);
  }

  Future<bool> deleteProjectOption(int id) async {
    final repository = ref.read(projectOptionRepositoryProvider);
    return repository.delete(id);
  }
}

@riverpod
Stream<List<ProjectOption>> watchAllProjectOptions(
  Ref ref,
  ProjectOptionSearchParams searchParams,
) {
  final repository = ref.watch(projectOptionRepositoryProvider);
  return repository.watchAll(searchParams);
}
