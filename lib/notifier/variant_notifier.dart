import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/model/entities/component_variant.dart';
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
