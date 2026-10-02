import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shop_repository.g.dart';

@riverpod
ShopRepository shopRepository(Ref ref) => ShopRepository();

class ShopRepository {
  final _db = ObjectboxService.instance;
  final _shopBox = ObjectboxService.instance.get<Shop>();

  List<Shop> all() =>
      _shopBox.getAll()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Danh sách shop (kèm số tuỳ chọn mua) có lọc theo tên.
  Stream<List<Shop>> watchAll({
    String name = "",
    SearchOptions searchOptions = const SearchOptions(),
  }) {
    final search = TextSearch(name, searchOptions);
    return _db
        .watchTables([
          _db.store.watch<Shop>(),
          _db.store.watch<ComponentOption>(),
        ])
        .map((_) => search.filter(all(), (s) => s.name));
  }

  Shop? findByName(String name, {int excludeId = 0}) {
    final key = name.trim().toLowerCase();
    return _shopBox
        .getAll()
        .where((s) => s.id != excludeId && s.name.trim().toLowerCase() == key)
        .firstOrNull;
  }

  /// Shop có tên [name] (không phân biệt hoa thường), tạo mới nếu chưa có.
  Shop findOrCreate(String name) {
    final existing = findByName(name);
    if (existing != null) return existing;
    final shop = Shop(name: name.trim());
    _shopBox.put(shop);
    return shop;
  }

  void _validate(Shop shop) {
    shop.name = shop.name.trim();
    if (shop.name.isEmpty) {
      throw ValidationException("Tên shop không được trống");
    }
    final duplicate = findByName(shop.name, excludeId: shop.id);
    if (duplicate != null) {
      throw EntityAlreadyExistsException(
        "Shop '${duplicate.name}' đã tồn tại. Dùng \"Gộp vào\" nếu muốn hợp nhất.",
      );
    }
  }

  Future<int> add(Shop shop) async {
    shop.id = 0;
    _validate(shop);
    return _shopBox.put(shop);
  }

  Future<int> update(Shop shop) async {
    if (_shopBox.get(shop.id) == null) {
      throw EntityNotFoundException("Không tìm thấy shop ${shop.id}");
    }
    _validate(shop);
    return _shopBox.put(shop);
  }

  /// Chuyển mọi tuỳ chọn mua của [fromId] sang [intoId] rồi xoá [fromId].
  Future<int> merge(int fromId, int intoId) async {
    if (fromId == intoId) return 0;
    if (_shopBox.get(intoId) == null) {
      throw EntityNotFoundException("Không tìm thấy shop $intoId");
    }
    return _db.store.runInTransaction(TxMode.write, () {
      final optionBox = _db.get<ComponentOption>();
      final options = optionBox
          .query(ComponentOption_.shop.equals(fromId))
          .findAndClose();
      for (final o in options) {
        o.shop.targetId = intoId;
      }
      optionBox.putMany(options);
      _shopBox.remove(fromId);
      return options.length;
    });
  }

  /// Xoá shop. Các tuỳ chọn mua của shop này thành "chưa ghi shop".
  Future<bool> delete(int id) async {
    if (_shopBox.get(id) == null) {
      throw EntityNotFoundException("Không tìm thấy shop $id");
    }
    return _shopBox.remove(id);
  }
}
