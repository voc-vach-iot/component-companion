import 'package:component_companion/data/project_item_repository.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/search_params/project_item_search_params.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_item_notifier.g.dart';

@riverpod
class ProjectItemNotifier extends _$ProjectItemNotifier {
  @override
  void build() {}

  Future<int> addProjectItem(ProjectItem projectItem) async {
    final repository = ref.read(projectItemRepositoryProvider);
    return repository.add(projectItem);
  }

  Future<int> updateProjectItem(ProjectItem projectItem) async {
    final repository = ref.read(projectItemRepositoryProvider);
    return await repository.update(projectItem);
  }

  Future<bool> deleteProjectItem(int id) async {
    final repository = ref.read(projectItemRepositoryProvider);
    return await repository.delete(id);
  }
}

@riverpod
Stream<List<ProjectItem>> watchAllProjectItems(
  Ref ref,
  ProjectItemSearchParams searchParams,
) {
  final repository = ref.watch(projectItemRepositoryProvider);
  return repository.watchAll(searchParams);
}
