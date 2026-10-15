import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/copy_name.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_option_repository.g.dart';

@riverpod
ProjectOptionRepository projectOptionRepository(Ref ref) =>
    ProjectOptionRepository();

class ProjectOptionRepository {
  final _db = ObjectboxService.instance;
  final _projectOptionBox = ObjectboxService.instance.get<ProjectOption>();

  /// Thêm phương án vào nhóm. Nhóm chưa chọn phương án nào => chọn luôn.
  Future<int> add(ProjectOption projectOption) async {
    // Đối tượng mới tạo chưa gắn store: phải attach trước khi đọc quan hệ
    projectOption.group.attach(_db.store);
    projectOption.project.attach(_db.store);
    final group = _db.get<ProjectGroup>().get(projectOption.group.targetId);
    if (group == null) {
      throw EntityNotFoundException("Nhóm lựa chọn không tồn tại");
    }
    projectOption
      ..id = 0
      ..name = projectOption.name.trim();
    projectOption.project.targetId = group.project.targetId;
    _validateName(projectOption);

    return _db.store.runInTransaction(TxMode.write, () {
      final id = _projectOptionBox.put(projectOption);
      if (group.selectedOption == null || group.selected.targetId == 0) {
        group.selected.targetId = id;
        _db.get<ProjectGroup>().put(group);
      }
      return id;
    });
  }

  Future<int> update(ProjectOption projectOption) async {
    final existing = _projectOptionBox.get(projectOption.id);
    if (existing == null) {
      throw EntityNotFoundException("Phương án không tồn tại");
    }
    existing
      ..name = projectOption.name.trim()
      ..description = projectOption.description.trim();
    _validateName(existing);
    return _projectOptionBox.put(existing);
  }

  void _validateName(ProjectOption option) {
    if (option.name.isEmpty) {
      throw ValidationException("Tên phương án không được để trống");
    }
    // So trong Dart: ObjectBox chỉ bỏ qua hoa thường với chữ ASCII
    final name = option.name.toLowerCase();
    final duplicate = _projectOptionBox
        .query(ProjectOption_.group.equals(option.group.targetId))
        .findAndClose()
        .any((o) => o.id != option.id && o.name.toLowerCase() == name);
    if (duplicate) {
      throw EntityAlreadyExistsException(
        "Phương án '${option.name}' đã có trong nhóm",
      );
    }
  }

  /// Nhân bản phương án kèm linh kiện (VD "Pin 2000mAh" từ "Pin 1000mAh" rồi
  /// chỉ đổi biến thể). Trả về id phương án mới.
  Future<int> duplicate(int id) async {
    final source = _projectOptionBox.get(id);
    if (source == null) {
      throw EntityNotFoundException("Phương án không tồn tại");
    }
    final siblings = _projectOptionBox
        .query(ProjectOption_.group.equals(source.group.targetId))
        .findAndClose()
        .map((o) => o.name.toLowerCase())
        .toSet();
    return _db.store.runInTransaction(TxMode.write, () {
      final copy =
          ProjectOption(
              name: nextCopyName(
                source.name,
                (c) => siblings.contains(c.toLowerCase()),
              ),
              description: source.description,
            )
            ..project.targetId = source.project.targetId
            ..group.targetId = source.group.targetId;
      final newId = _projectOptionBox.put(copy);
      _db.get<ProjectItem>().putMany([
        for (final item in source.items)
          ProjectItem(quantity: item.quantity)
            ..component.targetId = item.component.targetId
            ..variant.targetId = item.variant.targetId
            ..componentOption.targetId = item.componentOption.targetId
            ..projectOption.targetId = newId,
      ]);
      return newId;
    });
  }

  /// Xoá phương án kèm linh kiện. Đang được chọn => nhóm chuyển sang phương
  /// án còn lại đầu tiên.
  Future<bool> delete(int id) async {
    final existing = _projectOptionBox.get(id);
    if (existing == null) {
      throw EntityNotFoundException("Phương án không tồn tại");
    }

    return _db.store.runInTransaction(TxMode.write, () {
      // Đọc trước khi xoá: ObjectBox tự gỡ ToOne đang trỏ tới bản ghi bị xoá
      final group = existing.group.target;
      final wasSelected = group?.selected.targetId == id;
      _db
          .get<ProjectItem>()
          .query(ProjectItem_.projectOption.equals(id))
          .build()
        ..remove()
        ..close();
      final removed = _projectOptionBox.remove(id);
      if (group != null && wasSelected) {
        group.selected.targetId =
            _projectOptionBox
                .query(ProjectOption_.group.equals(group.id))
                .getIdsAndClose()
                .firstOrNull ??
            0;
        _db.get<ProjectGroup>().put(group);
      }
      return removed;
    });
  }
}
