import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/search_params/component_option_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'component_option_repository.g.dart';

@riverpod
ComponentOptionRepository componentOptionRepository(Ref ref) =>
    ComponentOptionRepository();

class ComponentOptionRepository {
  final _db = ObjectboxService.instance;
  final _componentOptionBox = ObjectboxService.instance.get<ComponentOption>();
  final _priceBox = ObjectboxService.instance.get<PriceRecord>();

  List<ComponentOption> _find(ComponentOptionSearchParams searchParams) {
    final query = searchParams.componentId == null
        ? _componentOptionBox.query()
        : _componentOptionBox.query(
            ComponentOption_.component.equals(searchParams.componentId!),
          );
    return query.findAndClose();
  }

  /// Tuỳ chọn của linh kiện, rẻ nhất (theo đơn giá) đứng đầu để dễ so sánh.
  Stream<List<ComponentOption>> watchAll(
    ComponentOptionSearchParams searchParams,
  ) {
    return _db
        .watchTables([
          _db.store.watch<ComponentOption>(),
          _db.store.watch<PriceRecord>(),
          _db.store.watch<Shop>(),
          _db.store.watch<ComponentVariant>(),
        ])
        .map(
          (_) => _find(searchParams)
            ..sort((a, b) {
              final byPrice = a.pricePerUnit.compareTo(b.pricePerUnit);
              return byPrice != 0 ? byPrice : a.id.compareTo(b.id);
            }),
        );
  }

  Stream<Map<int, ComponentOption>> watchAllAsMap(
    ComponentOptionSearchParams? searchParams,
  ) {
    searchParams ??= ComponentOptionSearchParams();
    return _db
        .watchTables([_db.store.watch<ComponentOption>()])
        .map((_) => {for (final o in _find(searchParams!)) o.id: o});
  }

  /// Bản đọc mới từ DB (để sửa mà không đụng vào đối tượng đang hiển thị).
  ComponentOption? get(int id) => _componentOptionBox.get(id);

  List<PriceRecord> priceHistory(int optionId) =>
      _priceBox.query(PriceRecord_.option.equals(optionId)).findAndClose()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  Set<int> _variantIds(ComponentOption o) =>
      o.variants.map((v) => v.id).toSet();

  void _validate(ComponentOption option) {
    // Đối tượng mới tạo chưa gắn store: phải attach trước khi đọc targetId
    option.component.attach(_db.store);
    option.shop.attach(_db.store);
    final component = _db.get<Component>().get(option.component.targetId);
    if (component == null) {
      throw EntityNotFoundException("Không tìm thấy linh kiện của tùy chọn");
    }
    option.name = option.name.trim();
    if (option.unitsPerPack <= 0) {
      throw ValidationException("Số cái mỗi gói phải lớn hơn 0");
    }
    if (component.variants.isNotEmpty && option.variants.isEmpty) {
      throw ValidationException("Hãy chọn ít nhất 1 biến thể áp dụng");
    }

    // Trùng khi cùng shop + tên + quy cách + đúng tập biến thể. Cùng tên nhưng
    // khác biến thể (VD "Gói 20 cái" cho 5mm và 8mm giá khác nhau) vẫn hợp lệ.
    final ids = _variantIds(option);
    final duplicate = _componentOptionBox
        .query(
          ComponentOption_.component.equals(component.id) &
              ComponentOption_.name.equals(option.name) &
              ComponentOption_.shop.equals(option.shop.targetId) &
              ComponentOption_.unitsPerPack.equals(option.unitsPerPack) &
              ComponentOption_.id.notEquals(option.id),
        )
        .findAndClose()
        .where((o) {
          final other = _variantIds(o);
          return other.length == ids.length && other.containsAll(ids);
        })
        .firstOrNull;
    if (duplicate != null) {
      throw EntityAlreadyExistsException(
        "Tùy chọn '${option.displayName}' cho đúng các biến thể này đã tồn tại",
      );
    }
  }

  void _recordPrice(ComponentOption option, DateTime at) {
    _priceBox.put(
      PriceRecord(
        pricePerPack: option.pricePerPack,
        unitsPerPack: option.unitsPerPack,
        recordedAt: at,
      )..option.targetId = option.id,
    );
  }

  void _clearHistory(int optionId) {
    _priceBox.query(PriceRecord_.option.equals(optionId)).build()
      ..remove()
      ..close();
  }

  Future<int> add(ComponentOption componentOption) async {
    componentOption.id = 0;
    _validate(componentOption);

    return _db.store.runInTransaction(TxMode.write, () {
      final now = DateTime.now();
      componentOption.priceCheckedAt = now;
      final id = _componentOptionBox.put(componentOption);
      _recordPrice(componentOption, now);
      return id;
    });
  }

  /// Cập nhật tuỳ chọn.
  /// - Chỉ đổi giá => ghi thêm lịch sử giá.
  /// - Đổi shop / quy cách / số cái mỗi gói => coi như chào giá khác: lịch sử
  ///   cũ bị xoá, bắt đầu lại từ giá hiện tại.
  Future<int> update(ComponentOption componentOption) async {
    final existing = _componentOptionBox.get(componentOption.id);
    if (existing == null) {
      throw EntityNotFoundException(
        "Không tìm thấy ComponentOption với id ${componentOption.id}",
      );
    }
    _validate(componentOption);

    return _db.store.runInTransaction(TxMode.write, () {
      final now = DateTime.now();
      final identityChanged =
          existing.shop.targetId != componentOption.shop.targetId ||
          existing.unitsPerPack != componentOption.unitsPerPack ||
          existing.name.trim() != componentOption.name.trim();
      final priceChanged =
          existing.pricePerPack != componentOption.pricePerPack;

      if (identityChanged) {
        _clearHistory(componentOption.id);
      }
      if (identityChanged || priceChanged) {
        componentOption.priceCheckedAt = now;
        _recordPrice(componentOption, now);
      }
      return _componentOptionBox.put(componentOption);
    });
  }

  /// Xác nhận giá hiện tại vẫn đúng (đã kiểm tra lại trên shop hôm nay).
  Future<int> confirmPrice(int id) async {
    final option = _componentOptionBox.get(id);
    if (option == null) {
      throw EntityNotFoundException(
        "Không tìm thấy ComponentOption với id $id",
      );
    }
    return _db.store.runInTransaction(TxMode.write, () {
      option.priceCheckedAt = DateTime.now();
      _recordPrice(option, option.priceCheckedAt!);
      return _componentOptionBox.put(option);
    });
  }

  Future<bool> delete(int id) async {
    final option = _componentOptionBox.get(id);
    if (option == null) {
      throw EntityNotFoundException(
        "Không tìm thấy ComponentOption với id $id",
      );
    }
    return _db.store.runInTransaction(TxMode.write, () {
      _clearHistory(id);
      return _componentOptionBox.remove(id);
    });
  }
}
