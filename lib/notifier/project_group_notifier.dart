import 'package:component_companion/data/project_group_repository.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_group_notifier.g.dart';

@riverpod
class ProjectGroupNotifier extends _$ProjectGroupNotifier {
  @override
  void build() {}

  Future<int> addGroup(ProjectGroup group, List<String> optionNames) =>
      ref.read(projectGroupRepositoryProvider).add(group, optionNames);

  Future<int> updateGroup(ProjectGroup group) =>
      ref.read(projectGroupRepositoryProvider).update(group);

  Future<void> select(int optionId) =>
      ref.read(projectGroupRepositoryProvider).select(optionId);

  Future<void> move(int groupId, int delta) =>
      ref.read(projectGroupRepositoryProvider).move(groupId, delta);

  Future<bool> deleteGroup(int id) =>
      ref.read(projectGroupRepositoryProvider).delete(id);
}

@riverpod
Stream<List<ProjectGroup>> watchProjectGroups(Ref ref, int projectId) =>
    ref.watch(projectGroupRepositoryProvider).watchByProject(projectId);
