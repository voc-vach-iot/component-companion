import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/model/variant.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'variant_notifier.g.dart';

@riverpod
class VariantNotifier extends _$VariantNotifier {
  @override
  void build() {}

  Future<int> addVariant(ComponentVariant variant) =>
      ref.read(variantRepositoryProvider).add(variant);

  Future<int> updateVariant(ComponentVariant variant) =>
      ref.read(variantRepositoryProvider).update(variant);

  Future<int> addVariants(
    int componentId,
    List<VariantSelection> selections, {
    int lowStockThreshold = 0,
  }) => ref
      .read(variantRepositoryProvider)
      .addMany(componentId, selections, lowStockThreshold: lowStockThreshold);

  Future<int> adjustStock(int variantId, int delta) =>
      ref.read(variantRepositoryProvider).adjustStock(variantId, delta);

  Future<bool> deleteVariant(int id) =>
      ref.read(variantRepositoryProvider).delete(id);
}

@riverpod
Stream<List<ComponentVariant>> watchVariantsOfComponent(
  Ref ref,
  int componentId,
) {
  final variantRepository = ref.watch(variantRepositoryProvider);
  return variantRepository.watchByComponent(componentId);
}

/// Biến thể có hàng đang về (đã đặt, chưa nhận).
@riverpod
Stream<List<ComponentVariant>> watchIncomingVariants(Ref ref) =>
    ref.watch(variantRepositoryProvider).watchIncoming();

/// Nhật ký kho của 1 biến thể (null = toàn bộ), mới nhất trước.
@riverpod
Stream<List<StockLog>> watchStockLogs(
  Ref ref, {
  int? variantId,
  int limit = 0,
}) => ref
    .watch(variantRepositoryProvider)
    .watchLogs(variantId: variantId, limit: limit);
