import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/search_params/component_option_search_params.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/copy_name.dart';
import 'package:component_companion/util/text_search.dart';
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
    return TextSearch(
      searchParams.name,
    ).filter(query.findAndClose(), (o) => "${o.shop} ${o.name}");
  }

  /// Tuỳ chọn của linh kiện, rẻ nhất (theo đơn giá) đứng đầu để dễ so sánh.
  Stream<List<ComponentOption>> watchAll(
    ComponentOptionSearchParams searchParams,
  ) {
    // Card tuỳ chọn hiển thị xu hướng giá => lắng nghe cả lịch sử giá
    return _db
        .watchTables([
          _db.store.watch<ComponentOption>(),
          _db.store.watch<PriceRecord>(),
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

  /// Tên các shop đã từng nhập (gợi ý khi thêm tuỳ chọn mới).
  List<String> distinctShops() {
    final shops = <String>{};
    for (final option in _componentOptionBox.getAll()) {
      final shop = option.shop.trim();
      if (shop.isNotEmpty) shops.add(shop);
    }
    return shops.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<PriceRecord> priceHistory(int optionId) =>
      _priceBox.query(PriceRecord_.option.equals(optionId)).findAndClose()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  void _checkDuplicate(ComponentOption option) {
    final duplicate = _componentOptionBox
        .query(
          ComponentOption_.name.equals(option.name) &
              ComponentOption_.shop.equals(option.shop) &
              ComponentOption_.component.equals(option.component.targetId) &
              ComponentOption_.id.notEquals(option.id),
        )
        .findFirstAndClose();
    if (duplicate != null) {
      final shop = option.shop.isEmpty ? "" : " của shop '${option.shop}'";
      throw EntityAlreadyExistsException(
        "Tùy chọn '${option.name}'$shop đã tồn tại",
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

  Future<int> add(ComponentOption componentOption) async {
    componentOption.id = 0;
    _checkDuplicate(componentOption);

    return _db.store.runInTransaction(TxMode.write, () {
      final now = DateTime.now();
      componentOption.priceCheckedAt = now;
      final id = _componentOptionBox.put(componentOption);
      _recordPrice(componentOption, now);
      return id;
    });
  }

  /// Cập nhật tuỳ chọn. Nếu giá / số lượng mỗi gói thay đổi thì ghi lịch sử giá.
  Future<int> update(ComponentOption componentOption) async {
    final existingOption = _componentOptionBox.get(componentOption.id);
    if (existingOption == null) {
      throw EntityNotFoundException(
        "Không tìm thấy ComponentOption với id ${componentOption.id}",
      );
    }
    _checkDuplicate(componentOption);

    return _db.store.runInTransaction(TxMode.write, () {
      final priceChanged =
          existingOption.pricePerPack != componentOption.pricePerPack ||
          existingOption.unitsPerPack != componentOption.unitsPerPack;
      if (priceChanged) {
        componentOption.priceCheckedAt = DateTime.now();
        _recordPrice(componentOption, componentOption.priceCheckedAt!);
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

  /// Nhân bản tuỳ chọn trong cùng linh kiện (VD để nhập giá của shop khác).
  Future<int> clone(int id) async {
    final source = _componentOptionBox.get(id);
    if (source == null) {
      throw EntityNotFoundException(
        "Không tìm thấy ComponentOption với id $id",
      );
    }

    final componentId = source.component.targetId;
    final copy = ComponentOption(
      name: nextCopyName(
        source.name,
        (name) =>
            _componentOptionBox
                .query(
                  ComponentOption_.name.equals(name) &
                      ComponentOption_.shop.equals(source.shop) &
                      ComponentOption_.component.equals(componentId),
                )
                .findFirstAndClose() !=
            null,
      ),
      unitsPerPack: source.unitsPerPack,
      pricePerPack: source.pricePerPack,
      link: source.link,
      shop: source.shop,
      availabilityJson: source.availabilityJson,
    )..component.targetId = componentId;
    return add(copy);
  }

  Future<bool> delete(int id) async {
    final option = _componentOptionBox.get(id);
    if (option == null) {
      throw EntityNotFoundException(
        "Không tìm thấy ComponentOption với id $id",
      );
    }
    return _db.store.runInTransaction(TxMode.write, () {
      _priceBox.query(PriceRecord_.option.equals(id)).build()
        ..remove()
        ..close();
      return _componentOptionBox.remove(id);
    });
  }
}
