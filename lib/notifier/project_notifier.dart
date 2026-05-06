import 'package:component_companion/data/project_repository.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/search_params/project_search_params.dart';
import 'package:component_companion/notifier/project_option_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_notifier.g.dart';

@riverpod
class ProjectNotifier extends _$ProjectNotifier {
  @override
  void build() {}

  Future<int> addProject(Project project) async {
    final repository = ref.read(projectRepositoryProvider);
    return await repository.add(project);
  }

  Future<int> updateProject(Project project) async {
    final repository = ref.read(projectRepositoryProvider);
    return await repository.update(project);
  }

  Future<bool> deleteProject(int projectId) async {
    final repository = ref.read(projectRepositoryProvider);
    return await repository.delete(projectId);
  }
}

@riverpod
class ProjectEventNotifier extends _$ProjectEventNotifier {
  @override
  int build() => 0;

  void notify() => state++;
}

@riverpod
Stream<PageResult<Project>> watchProjects(
  Ref ref,
  ProjectSearchParams searchParams,
) {
  ref.watch(projectOptionEventProvider);
  final repository = ref.watch(projectRepositoryProvider);
  return repository.watchPaged(searchParams);
}

@riverpod
Stream<Project?> watchProjectById(Ref ref, int projectId) {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.watchById(projectId);
}
