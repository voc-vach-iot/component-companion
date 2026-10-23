import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'power_supply_repository.g.dart';

@riverpod
PowerSupplyRepository powerSupplyRepository(Ref ref) => PowerSupplyRepository();

/// Danh sách nguồn cấp cho dải LED.
class PowerSupplyRepository {
  final _db = ObjectboxService.instance;
  final _box = ObjectboxService.instance.get<PowerSupply>();

  List<PowerSupply> all() =>
      _box.getAll()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Stream<List<PowerSupply>> watchAll() =>
      _db.watchTables([_db.store.watch<PowerSupply>()]).map((_) => all());

  void _validate(PowerSupply supply) {
    supply.name = supply.name.trim();
    if (supply.name.isEmpty) {
      throw ValidationException("Tên nguồn không được trống");
    }
    if (supply.voltage <= 0 || supply.currentA <= 0) {
      throw ValidationException("Điện áp và dòng phải lớn hơn 0");
    }
    if (supply.derate <= 0 || supply.derate > 1) {
      throw ValidationException("Tỉ lệ sử dụng phải trong khoảng (0, 1]");
    }
  }

  Future<int> add(PowerSupply supply) async {
    supply.id = 0;
    _validate(supply);
    return _box.put(supply);
  }

  Future<int> update(PowerSupply supply) async {
    if (_box.get(supply.id) == null) {
      throw EntityNotFoundException("Không tìm thấy nguồn ${supply.id}");
    }
    _validate(supply);
    return _box.put(supply);
  }

  /// Xoá nguồn; kho đang dùng nguồn này thành "chưa chọn nguồn".
  Future<bool> delete(int id) async {
    if (_box.get(id) == null) {
      throw EntityNotFoundException("Không tìm thấy nguồn $id");
    }
    return _db.store.runInTransaction(TxMode.write, () {
      final storageBox = _db.get<Storage>();
      final storages = storageBox
          .query(Storage_.powerSupply.equals(id))
          .findAndClose();
      for (final s in storages) {
        s.powerSupply.targetId = 0;
      }
      storageBox.putMany(storages);
      return _box.remove(id);
    });
  }
}
