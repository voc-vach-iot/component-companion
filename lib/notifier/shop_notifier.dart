import 'package:component_companion/data/shop_repository.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shop_notifier.g.dart';

@riverpod
class ShopNotifier extends _$ShopNotifier {
  @override
  void build() {}

  Future<int> addShop(Shop shop) => ref.read(shopRepositoryProvider).add(shop);

  Future<int> updateShop(Shop shop) =>
      ref.read(shopRepositoryProvider).update(shop);

  /// Chuyển tuỳ chọn mua của [fromId] sang [intoId], trả về số tuỳ chọn đã chuyển.
  Future<int> mergeShop(int fromId, int intoId) =>
      ref.read(shopRepositoryProvider).merge(fromId, intoId);

  Future<bool> deleteShop(int id) =>
      ref.read(shopRepositoryProvider).delete(id);
}

@riverpod
Stream<List<Shop>> watchAllShops(
  Ref ref, {
  String name = "",
  SearchOptions searchOptions = const SearchOptions(),
}) {
  final shopRepository = ref.watch(shopRepositoryProvider);
  return shopRepository.watchAll(name: name, searchOptions: searchOptions);
}
