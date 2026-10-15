import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_group_repository.g.dart';

@riverpod
ProjectGroupRepository projectGroupRepository(Ref ref) =>
    ProjectGroupRepository();

class ProjectGroupRepository {
  final _db = ObjectboxService.instance;
  final _groupBox = ObjectboxService.instance.get<ProjectGroup>();

  /// Nhóm lựa chọn của dự án (kèm phương án + linh kiện để tính giá).
  Stream<List<ProjectGroup>> watchByProject(int projectId) => _db
      .watchTables([
        _db.store.watch<ProjectGroup>(),
        _db.store.watch<ProjectOption>(),
        _db.store.watch<ProjectItem>(),
        _db.store.watch<Component>(),
        _db.store.watch<ComponentOption>(),
        _db.store.watch<ComponentVariant>(),
        _db.store.watch<Shop>(),
      ])
      .map((_) => byProject(projectId));

  List<ProjectGroup> byProject(int projectId) =>
      _groupBox.query(ProjectGroup_.project.equals(projectId)).findAndClose()
        ..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
        });

  ProjectGroup? get(int id) => _groupBox.get(id);

  /// Tạo nhóm kèm các phương án ban đầu (ít nhất 1). Phương án đầu được chọn.
  Future<int> add(ProjectGroup group, List<String> optionNames) async {
    group.project.attach(_db.store);
    final projectId = group.project.targetId;
    if (_db.get<Project>().get(projectId) == null) {
      throw EntityNotFoundException("Dự án không tồn tại");
    }
    group.name = group.name.trim();
    _validateName(group, projectId);

    final names = <String>[];
    for (final raw in optionNames) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      if (names.any((n) => n.toLowerCase() == name.toLowerCase())) {
        throw EntityAlreadyExistsException("Phương án '$name' bị trùng");
      }
      names.add(name);
    }
    if (names.isEmpty) names.add("Phương án 1");

    return _db.store.runInTransaction(TxMode.write, () {
      final others = byProject(projectId);
      group
        ..id = 0
        ..sortOrder = others.isEmpty ? 0 : others.last.sortOrder + 1;
      final id = _groupBox.put(group);
      final options = [
        for (final name in names)
          ProjectOption(name: name)
            ..project.targetId = projectId
            ..group.targetId = id,
      ];
      _db.get<ProjectOption>().putMany(options);
      group.selected.targetId = options.first.id;
      _groupBox.put(group);
      return id;
    });
  }

  /// Đổi tên nhóm.
  Future<int> update(ProjectGroup group) async {
    final existing = _groupBox.get(group.id);
    if (existing == null) {
      throw EntityNotFoundException("Nhóm lựa chọn không tồn tại");
    }
    existing.name = group.name.trim();
    _validateName(existing, existing.project.targetId);
    return _groupBox.put(existing);
  }

  void _validateName(ProjectGroup group, int projectId) {
    if (group.name.isEmpty) {
      throw ValidationException("Tên nhóm không được để trống");
    }
    final duplicate = byProject(projectId).any(
      (g) =>
          g.id != group.id && g.name.toLowerCase() == group.name.toLowerCase(),
    );
    if (duplicate) {
      throw EntityAlreadyExistsException(
        "Nhóm '${group.name}' đã có trong dự án",
      );
    }
  }

  /// Dùng phương án [optionId] cho nhóm của nó.
  Future<void> select(int optionId) async {
    final option = _db.get<ProjectOption>().get(optionId);
    final group = option?.group.target;
    if (option == null || group == null) {
      throw EntityNotFoundException("Phương án không tồn tại");
    }
    if (group.selected.targetId == optionId) return;
    group.selected.targetId = optionId;
    _groupBox.put(group);
  }

  /// Đổi chỗ nhóm với nhóm liền trước (-1) / liền sau (+1).
  Future<void> move(int groupId, int delta) async {
    final group = _groupBox.get(groupId);
    if (group == null) return;
    final list = byProject(group.project.targetId);
    final from = list.indexWhere((g) => g.id == groupId);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) return;
    list.insert(to, list.removeAt(from));
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
    }
    _groupBox.putMany(list);
  }

  /// Xoá nhóm kèm mọi phương án và linh kiện bên trong.
  Future<bool> delete(int id) async {
    if (_groupBox.get(id) == null) {
      throw EntityNotFoundException("Nhóm lựa chọn không tồn tại");
    }
    return _db.store.runInTransaction(TxMode.write, () {
      final optionIds = _db
          .get<ProjectOption>()
          .query(ProjectOption_.group.equals(id))
          .getIdsAndClose();
      if (optionIds.isNotEmpty) {
        _db
            .get<ProjectItem>()
            .query(ProjectItem_.projectOption.anyOf(optionIds))
            .build()
          ..remove()
          ..close();
        _db.get<ProjectOption>().removeMany(optionIds);
      }
      return _groupBox.remove(id);
    });
  }
}
