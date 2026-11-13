import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/compartments.dart';
import 'package:component_companion/util/led_order.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_repository.g.dart';

@riverpod
StorageRepository storageRepository(Ref ref) => StorageRepository();

/// Kho, khay đặt trong kho, thứ tự LED và chỗ cất của biến thể.
class StorageRepository {
  final _db = ObjectboxService.instance;
  final _storageBox = ObjectboxService.instance.get<Storage>();
  final _trayBox = ObjectboxService.instance.get<StorageTray>();

  List<Storage> all() =>
      _storageBox.getAll()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Storage? get(int id) => _storageBox.get(id);

  StorageTray? tray(int id) => _trayBox.get(id);

  /// Khay của kho, sắp theo vị trí (trên → dưới, trái → phải).
  List<StorageTray> traysOf(int storageId) =>
      _trayBox.query(StorageTray_.storage.equals(storageId)).findAndClose()
        ..sort((a, b) {
          final byY = a.yMm.compareTo(b.yMm);
          return byY != 0 ? byY : a.xMm.compareTo(b.xMm);
        });

  /// Mọi bảng ảnh hưởng tới sơ đồ kho.
  Stream<void> _watchStorageTables() => _db.watchTables([
    _db.store.watch<Storage>(),
    _db.store.watch<StorageTray>(),
    _db.store.watch<TrayType>(),
    _db.store.watch<PowerSupply>(),
    _db.store.watch<ComponentVariant>(),
  ]);

  Stream<List<Storage>> watchAll() => _watchStorageTables().map((_) => all());

  Stream<List<StorageTray>> watchTrays(int storageId) =>
      _watchStorageTables().map((_) => traysOf(storageId));

  // ---------------------------------------------------------------------------
  // KHO
  // ---------------------------------------------------------------------------

  void _validate(Storage storage) {
    storage.name = storage.name.trim();
    if (storage.name.isEmpty) {
      throw ValidationException("Tên kho không được trống");
    }
    if (storage.widthMm <= 0 || storage.heightMm <= 0) {
      throw ValidationException("Kích thước kho phải lớn hơn 0");
    }
    if (storage.gridMm <= 0) {
      throw ValidationException("Bước lưới phải lớn hơn 0");
    }
    if (storage.ledCount < 1 || storage.ledCount > 255) {
      throw ValidationException("Số LED phải từ 1 đến 255");
    }
    if (storage.mAPerChannel <= 0 ||
        storage.idleMaPerLed < 0 ||
        storage.mcuMa < 0) {
      throw ValidationException("Thông số dòng điện không hợp lệ");
    }
    if (storage.lightTimeoutS < 1 || storage.lightTimeoutS > 3600) {
      throw ValidationException("Thời gian tự tắt phải từ 1 đến 3600 giây");
    }
    final usedLeds = traysOf(storage.id).where((t) => t.hasLed);
    final over = usedLeds.where((t) => t.ledIndex >= storage.ledCount);
    if (storage.id != 0 && over.isNotEmpty) {
      throw ValidationException(
        "Khay ${over.first.label} đang dùng LED số ${over.first.ledIndex + 1}, "
        "lớn hơn số LED mới",
      );
    }
  }

  Future<int> add(Storage storage) async {
    storage.id = 0;
    _validate(storage);
    return _storageBox.put(storage);
  }

  Future<int> update(Storage storage) async {
    if (_storageBox.get(storage.id) == null) {
      throw EntityNotFoundException("Không tìm thấy kho ${storage.id}");
    }
    _validate(storage);
    return _storageBox.put(storage);
  }

  /// Xoá kho cùng các khay; linh kiện cất trong đó thành "chưa có chỗ".
  Future<bool> delete(int id) async {
    if (_storageBox.get(id) == null) {
      throw EntityNotFoundException("Không tìm thấy kho $id");
    }
    return _db.store.runInTransaction(TxMode.write, () {
      _removeTrays(traysOf(id).map((t) => t.id).toList());
      return _storageBox.remove(id);
    });
  }

  // ---------------------------------------------------------------------------
  // KHAY
  // ---------------------------------------------------------------------------

  /// Tên khay chưa dùng trong kho, VD "A6-03" cho loại "Khay A6".
  String nextLabel(int storageId, TrayType type) {
    final prefix = type.name.replaceFirst(
      RegExp(r"^khay\s+", caseSensitive: false),
      "",
    );
    final used = traysOf(storageId).map((t) => t.label.toLowerCase()).toSet();
    for (var n = 1; ; n++) {
      final label = "$prefix-${n.toString().padLeft(2, "0")}";
      if (!used.contains(label.toLowerCase())) return label;
    }
  }

  Future<int> addTray(
    int storageId,
    int trayTypeId, {
    required double xMm,
    required double yMm,
    bool rotated = false,
    String? label,
  }) async {
    if (_storageBox.get(storageId) == null) {
      throw EntityNotFoundException("Không tìm thấy kho $storageId");
    }
    final type = _db.get<TrayType>().get(trayTypeId);
    if (type == null) {
      throw EntityNotFoundException("Không tìm thấy loại khay $trayTypeId");
    }
    final tray =
        StorageTray(
            xMm: xMm < 0 ? 0 : xMm,
            yMm: yMm < 0 ? 0 : yMm,
            rotated: rotated,
            label: (label ?? "").trim().isEmpty
                ? nextLabel(storageId, type)
                : label!.trim(),
          )
          ..storage.targetId = storageId
          ..trayType.targetId = trayTypeId;
    return _trayBox.put(tray);
  }

  /// Sửa khay (tên, loại, xoay, vị trí). LED đổi qua [setLed].
  Future<int> updateTray(StorageTray tray) async {
    final current = _trayBox.get(tray.id);
    if (current == null) {
      throw EntityNotFoundException("Không tìm thấy khay ${tray.id}");
    }
    tray.label = tray.label.trim();
    if (tray.label.isEmpty) {
      throw ValidationException("Tên khay không được trống");
    }
    final duplicate = traysOf(current.storage.targetId).any(
      (t) =>
          t.id != tray.id && t.label.toLowerCase() == tray.label.toLowerCase(),
    );
    if (duplicate) {
      throw EntityAlreadyExistsException(
        "Khay '${tray.label}' đã có trong kho",
      );
    }
    if (tray.xMm < 0) tray.xMm = 0;
    if (tray.yMm < 0) tray.yMm = 0;
    tray.storage.targetId = current.storage.targetId;
    tray.ledIndex = current.ledIndex;
    tray.removedDividers = current.removedDividers;

    // Đổi loại khay => lắp lại đủ vách; loại mới ít ngăn hơn thì linh kiện ở
    // ngăn bị mất dồn về ngăn cuối
    final typeChanged = tray.trayType.targetId != current.trayType.targetId;
    if (typeChanged) tray.removedDividers = 0;
    final type = _db.get<TrayType>().get(tray.trayType.targetId);
    final count = type == null
        ? null
        : (tray..trayType.target = type).compartmentCount;
    return _db.store.runInTransaction(TxMode.write, () {
      if (count != null) {
        final variants = current.variants
            .where((v) => v.compartmentIndex >= count)
            .toList();
        for (final v in variants) {
          v.compartmentIndex = count - 1;
        }
        _db.get<ComponentVariant>().putMany(variants);
      }
      return _trayBox.put(tray);
    });
  }

  /// Tháo / lắp vách ngăn của khay ([removed] xem [Compartments]). Linh kiện
  /// chuyển sang ngăn mới chứa khe đầu của ngăn cũ.
  Future<void> setRemovedDividers(int trayId, int removed) async {
    final tray = _trayBox.get(trayId);
    if (tray == null) {
      throw EntityNotFoundException("Không tìm thấy khay $trayId");
    }
    final type = tray.trayType.target;
    if (type == null || !type.removableDividers) {
      throw ValidationException("Loại khay này không tháo được vách ngăn");
    }
    final slots = type.compartmentCount;
    final valid = (1 << (slots - 1)) - 1;
    if (removed < 0 || removed & ~valid != 0) {
      throw ValidationException("Cách chia ngăn không hợp lệ");
    }
    final old = tray.removedDividers;
    _db.store.runInTransaction(TxMode.write, () {
      final variants = tray.variants.toList();
      for (final v in variants) {
        final slot = Compartments.firstSlot(slots, old, v.compartmentIndex);
        v.compartmentIndex = Compartments.ofSlot(slots, removed, slot);
      }
      _db.get<ComponentVariant>().putMany(variants);
      tray.removedDividers = removed;
      _trayBox.put(tray);
    });
  }

  /// Di chuyển nhiều khay một lúc (kéo thả).
  Future<void> moveTrays(Map<int, ({double x, double y})> positions) async {
    final trays = _trayBox
        .getMany(positions.keys.toList())
        .whereType<StorageTray>()
        .toList();
    for (final t in trays) {
      final p = positions[t.id]!;
      t.xMm = p.x < 0 ? 0 : p.x;
      t.yMm = p.y < 0 ? 0 : p.y;
    }
    _trayBox.putMany(trays);
  }

  /// Nhân bản khay (không kèm LED và linh kiện), đặt lệch [dx], [dy] mm.
  Future<List<int>> duplicateTrays(
    List<int> ids, {
    double dx = 0,
    double dy = 0,
  }) async {
    final ids2 = <int>[];
    for (final t in _trayBox.getMany(ids).whereType<StorageTray>()) {
      final type = t.trayType.target;
      if (type == null) continue;
      ids2.add(
        await addTray(
          t.storage.targetId,
          type.id,
          xMm: t.xMm + dx,
          yMm: t.yMm + dy,
          rotated: t.rotated,
        ),
      );
    }
    return ids2;
  }

  void _removeTrays(List<int> ids) {
    if (ids.isEmpty) return;
    final variantBox = _db.get<ComponentVariant>();
    final variants = variantBox
        .query(ComponentVariant_.tray.anyOf(ids))
        .findAndClose();
    for (final v in variants) {
      v.tray.targetId = 0;
      v.compartmentIndex = 0;
    }
    variantBox.putMany(variants);
    _trayBox.removeMany(ids);
  }

  /// Xoá khay; linh kiện cất trong đó thành "chưa có chỗ".
  Future<int> deleteTrays(List<int> ids) async {
    return _db.store.runInTransaction(TxMode.write, () {
      _removeTrays(ids);
      return ids.length;
    });
  }

  // ---------------------------------------------------------------------------
  // LED
  // ---------------------------------------------------------------------------

  /// Gắn LED số [ledIndex] cho khay (-1 = bỏ LED). Nếu LED đã thuộc khay khác
  /// trong cùng kho thì 2 khay đổi LED cho nhau.
  Future<void> setLed(int trayId, int ledIndex) async {
    final tray = _trayBox.get(trayId);
    if (tray == null) {
      throw EntityNotFoundException("Không tìm thấy khay $trayId");
    }
    final storage = tray.storage.target;
    if (storage != null && ledIndex >= storage.ledCount) {
      throw ValidationException(
        "Kho chỉ có ${storage.ledCount} LED (đánh số 1–${storage.ledCount})",
      );
    }
    _db.store.runInTransaction(TxMode.write, () {
      if (ledIndex >= 0) {
        final other = traysOf(
          tray.storage.targetId,
        ).where((t) => t.id != trayId && t.ledIndex == ledIndex).firstOrNull;
        if (other != null) {
          other.ledIndex = tray.ledIndex;
          _trayBox.put(other);
        }
      }
      tray.ledIndex = ledIndex < 0 ? -1 : ledIndex;
      _trayBox.put(tray);
    });
  }

  /// Đánh số LED 0, 1, 2… cho mọi khay của kho theo [order]. Khay vượt quá số
  /// LED của kho thì bỏ LED. Trả về số khay đã gắn LED.
  Future<int> autoNumberLeds(int storageId, LedOrder order) async {
    final storage = _storageBox.get(storageId);
    if (storage == null) {
      throw EntityNotFoundException("Không tìm thấy kho $storageId");
    }
    final trays = traysOf(storageId);
    final ordered = sortTraysForLed([
      for (final t in trays)
        (id: t.id, x: t.xMm, y: t.yMm, w: t.frontWidthMm, h: t.frontHeightMm),
    ], order);
    final byId = {for (final t in trays) t.id: t};
    var assigned = 0;
    for (var i = 0; i < ordered.length; i++) {
      final t = byId[ordered[i]]!;
      t.ledIndex = i < storage.ledCount ? i : -1;
      if (t.hasLed) assigned++;
    }
    _trayBox.putMany(trays);
    return assigned;
  }

  /// Đánh số LED [start], [start]+1… cho các khay [trayIds] theo [order] và
  /// [corner]. Khay khác đang giữ LED trong dải thì bị bỏ LED nếu
  /// [clearConflicts], ngược lại ném [ValidationException].
  Future<void> numberLeds(
    int storageId,
    List<int> trayIds,
    int start,
    LedOrder order, {
    LedCorner corner = LedCorner.topLeft,
    bool clearConflicts = true,
  }) async {
    final storage = _storageBox.get(storageId);
    if (storage == null) {
      throw EntityNotFoundException("Không tìm thấy kho $storageId");
    }
    final idSet = trayIds.toSet();
    final all = traysOf(storageId);
    final chosen = all.where((t) => idSet.contains(t.id)).toList();
    if (chosen.isEmpty) return;
    if (start < 0) throw ValidationException("LED bắt đầu không hợp lệ");
    if (start + chosen.length > storage.ledCount) {
      throw ValidationException(
        "Cần LED ${start + 1}–${start + chosen.length} nhưng kho chỉ có "
        "${storage.ledCount} LED",
      );
    }
    final conflicts = ledConflicts(storageId, idSet, start, chosen.length);
    if (conflicts.isNotEmpty && !clearConflicts) {
      throw ValidationException(
        "LED trong dải đang thuộc khay ${conflicts.map((t) => t.label).join(", ")}",
      );
    }
    final ordered = sortTraysForLed(
      [
        for (final t in chosen)
          (id: t.id, x: t.xMm, y: t.yMm, w: t.frontWidthMm, h: t.frontHeightMm),
      ],
      order,
      corner: corner,
    );
    final byId = {for (final t in chosen) t.id: t};
    _db.store.runInTransaction(TxMode.write, () {
      for (final t in conflicts) {
        t.ledIndex = -1;
      }
      for (var i = 0; i < ordered.length; i++) {
        byId[ordered[i]]!.ledIndex = start + i;
      }
      _trayBox.putMany([...conflicts, ...chosen]);
    });
  }

  /// Khay ngoài [trayIds] đang giữ LED trong dải [start, start+count).
  List<StorageTray> ledConflicts(
    int storageId,
    Set<int> trayIds,
    int start,
    int count,
  ) => traysOf(storageId)
      .where(
        (t) =>
            !trayIds.contains(t.id) &&
            t.ledIndex >= start &&
            t.ledIndex < start + count,
      )
      .toList();

  /// Cộng [delta] vào LED của mọi khay có LED >= [from] (chèn / bỏ chỗ trống).
  Future<void> shiftLeds(int storageId, int from, int delta) async {
    final storage = _storageBox.get(storageId);
    if (storage == null) {
      throw EntityNotFoundException("Không tìm thấy kho $storageId");
    }
    if (delta == 0) return;
    final trays = traysOf(storageId);
    final moving = trays.where((t) => t.ledIndex >= from).toList();
    for (final t in moving) {
      final next = t.ledIndex + delta;
      if (next < 0) {
        throw ValidationException("Khay ${t.label} sẽ có LED âm");
      }
      if (next >= storage.ledCount) {
        throw ValidationException(
          "Khay ${t.label} sẽ vượt quá ${storage.ledCount} LED của kho",
        );
      }
      if (delta < 0 && next < from) {
        final clash = trays.where((o) => o.ledIndex >= 0 && o.ledIndex < from);
        if (clash.any((o) => o.ledIndex == next)) {
          throw ValidationException(
            "Dời lùi sẽ đè lên LED ${next + 1} của khay khác",
          );
        }
      }
    }
    for (final t in moving) {
      t.ledIndex += delta;
    }
    _trayBox.putMany(moving);
  }

  /// Ảnh chụp LED của kho: trayId → ledIndex.
  Map<int, int> ledSnapshot(int storageId) => {
    for (final t in traysOf(storageId)) t.id: t.ledIndex,
  };

  /// Khôi phục LED từ [ledSnapshot].
  Future<void> restoreLeds(Map<int, int> snapshot) async {
    final trays = _trayBox
        .getMany(snapshot.keys.toList())
        .whereType<StorageTray>()
        .toList();
    for (final t in trays) {
      t.ledIndex = snapshot[t.id]!;
    }
    _trayBox.putMany(trays);
  }

  /// Bỏ LED của mọi khay trong kho.
  Future<void> clearLeds(int storageId) async {
    final trays = traysOf(storageId);
    for (final t in trays) {
      t.ledIndex = -1;
    }
    _trayBox.putMany(trays);
  }

  // ---------------------------------------------------------------------------
  // CHỖ CẤT LINH KIỆN
  // ---------------------------------------------------------------------------

  /// Cất biến thể vào ngăn [compartmentIndex] của khay [trayId]
  /// (trayId = 0: bỏ chỗ cất).
  Future<void> place(
    int variantId,
    int trayId, {
    int compartmentIndex = 0,
  }) async {
    final variantBox = _db.get<ComponentVariant>();
    final variant = variantBox.get(variantId);
    if (variant == null) {
      throw EntityNotFoundException("Không tìm thấy biến thể $variantId");
    }
    if (trayId != 0) {
      final tray = _trayBox.get(trayId);
      if (tray == null) {
        throw EntityNotFoundException("Không tìm thấy khay $trayId");
      }
      if (compartmentIndex < 0 || compartmentIndex >= tray.compartmentCount) {
        throw ValidationException(
          "Khay ${tray.label} chỉ có ${tray.compartmentCount} ngăn",
        );
      }
    }
    variant.tray.targetId = trayId;
    variant.compartmentIndex = trayId == 0 ? 0 : compartmentIndex;
    variantBox.put(variant);
  }

  /// Chuyển đồ của ngăn nguồn sang ngăn đích: [swap] false = gộp vào đích,
  /// true = đổi chỗ đồ hai ngăn.
  Future<void> moveCompartment(
    int fromTrayId,
    int fromIndex,
    int toTrayId,
    int toIndex, {
    required bool swap,
  }) async {
    final from = _trayBox.get(fromTrayId);
    final to = _trayBox.get(toTrayId);
    if (from == null) {
      throw EntityNotFoundException("Không tìm thấy khay $fromTrayId");
    }
    if (to == null) {
      throw EntityNotFoundException("Không tìm thấy khay $toTrayId");
    }
    if (fromIndex < 0 || fromIndex >= from.compartmentCount) {
      throw ValidationException(
        "Khay ${from.label} chỉ có ${from.compartmentCount} ngăn",
      );
    }
    if (toIndex < 0 || toIndex >= to.compartmentCount) {
      throw ValidationException(
        "Khay ${to.label} chỉ có ${to.compartmentCount} ngăn",
      );
    }
    if (fromTrayId == toTrayId && fromIndex == toIndex) return;
    final variantBox = _db.get<ComponentVariant>();
    _db.store.runInTransaction(TxMode.write, () {
      final src = from.variants
          .where((v) => v.compartmentIndex == fromIndex)
          .toList();
      final dst = swap
          ? to.variants.where((v) => v.compartmentIndex == toIndex).toList()
          : <ComponentVariant>[];
      for (final v in src) {
        v.tray.targetId = toTrayId;
        v.compartmentIndex = toIndex;
      }
      for (final v in dst) {
        v.tray.targetId = fromTrayId;
        v.compartmentIndex = fromIndex;
      }
      variantBox.putMany([...src, ...dst]);
    });
  }

  /// Vị trí cất của các biến thể trong 2 khay: (variantId, trayId, ngăn).
  List<({int variantId, int trayId, int index})> placementsOf(
    List<int> trayIds,
  ) => [
    for (final id in trayIds.toSet())
      for (final v in _trayBox.get(id)?.variants ?? <ComponentVariant>[])
        (variantId: v.id, trayId: id, index: v.compartmentIndex),
  ];

  /// Đặt lại vị trí cất theo [placementsOf] (cho hoàn tác).
  Future<void> restorePlacements(
    List<({int variantId, int trayId, int index})> list,
  ) async {
    final box = _db.get<ComponentVariant>();
    final variants = box.getMany(list.map((e) => e.variantId).toList());
    for (var i = 0; i < list.length; i++) {
      final v = variants[i];
      if (v == null) continue;
      v.tray.targetId = list[i].trayId;
      v.compartmentIndex = list[i].index;
    }
    box.putMany(variants.whereType<ComponentVariant>().toList());
  }

  /// Biến thể chưa có chỗ cất, sắp theo tình trạng tồn (còn hàng → hết hàng →
  /// chưa ghi tồn) rồi theo tên. Trang kho lọc theo tình trạng.
  List<ComponentVariant> unplaced() {
    // Lọc trong Dart: biến thể tạo trước khi có kho thông minh không có giá
    // trị cho quan hệ `tray` (null) nên query `equals(0)` không khớp
    final list = _db
        .get<ComponentVariant>()
        .getAll()
        .where((v) => !v.hasPlace)
        .toList();
    final labels = {for (final v in list) v.id: v.fullLabel.toLowerCase()};
    return list..sort((a, b) {
      final byState = StockState.of(a).index.compareTo(StockState.of(b).index);
      return byState != 0 ? byState : labels[a.id]!.compareTo(labels[b.id]!);
    });
  }

  Stream<List<ComponentVariant>> watchUnplaced() => _db
      .watchTables([
        _db.store.watch<ComponentVariant>(),
        _db.store.watch<StorageTray>(),
      ])
      .map((_) => unplaced());

  /// Biến thể đang cất trong khay, theo ngăn.
  Map<int, List<ComponentVariant>> contentsOf(int trayId) {
    final tray = _trayBox.get(trayId);
    final result = <int, List<ComponentVariant>>{};
    if (tray == null) return result;
    for (final v in tray.variants) {
      result.putIfAbsent(v.compartmentIndex, () => []).add(v);
    }
    return result;
  }
}
