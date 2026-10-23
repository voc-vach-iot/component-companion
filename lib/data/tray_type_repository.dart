import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tray_type_repository.g.dart';

@riverpod
TrayTypeRepository trayTypeRepository(Ref ref) => TrayTypeRepository();

/// Loại khay (kích thước, số ngăn, màu LED).
class TrayTypeRepository {
  final _db = ObjectboxService.instance;
  final _box = ObjectboxService.instance.get<TrayType>();

  List<TrayType> all() =>
      _box.getAll()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Stream<List<TrayType>> watchAll() => _db
      .watchTables([
        _db.store.watch<TrayType>(),
        _db.store.watch<StorageTray>(),
      ])
      .map((_) => all());

  void _validate(TrayType type) {
    type.name = type.name.trim();
    if (type.name.isEmpty) {
      throw ValidationException("Tên loại khay không được trống");
    }
    if (type.widthMm <= 0 || type.depthMm <= 0 || type.heightMm <= 0) {
      throw ValidationException("Kích thước khay phải lớn hơn 0");
    }
    if (type.stackGapMm < 0) {
      throw ValidationException("Thanh kê không được âm");
    }
    if (type.compartmentCount < 1 || type.compartmentCount > 24) {
      throw ValidationException("Số ngăn phải từ 1 đến 24");
    }
    if (type.minBrightness < 0 ||
        type.maxBrightness > 255 ||
        type.minBrightness > type.maxBrightness) {
      throw ValidationException(
        "Độ sáng phải trong khoảng 0–255 và thấp nhất ≤ cao nhất",
      );
    }
    final key = type.name.toLowerCase();
    final duplicate = _box.getAll().any(
      (t) => t.id != type.id && t.name.trim().toLowerCase() == key,
    );
    if (duplicate) {
      throw EntityAlreadyExistsException("Loại khay '${type.name}' đã tồn tại");
    }
  }

  Future<int> add(TrayType type) async {
    type.id = 0;
    _validate(type);
    return _box.put(type);
  }

  Future<int> update(TrayType type) async {
    if (_box.get(type.id) == null) {
      throw EntityNotFoundException("Không tìm thấy loại khay ${type.id}");
    }
    _validate(type);
    return _box.put(type);
  }

  /// Chỉ xoá được loại khay chưa đặt khay nào trong kho.
  Future<bool> delete(int id) async {
    final type = _box.get(id);
    if (type == null) {
      throw EntityNotFoundException("Không tìm thấy loại khay $id");
    }
    if (type.trays.isNotEmpty) {
      throw ValidationException(
        "Loại khay '${type.name}' đang có ${type.trays.length} khay trong kho, "
        "hãy xoá các khay đó trước",
      );
    }
    return _box.remove(id);
  }
}
