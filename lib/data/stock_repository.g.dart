// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(stockRepository)
final stockRepositoryProvider = StockRepositoryProvider._();

final class StockRepositoryProvider
    extends
        $FunctionalProvider<StockRepository, StockRepository, StockRepository>
    with $Provider<StockRepository> {
  StockRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stockRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stockRepositoryHash();

  @$internal
  @override
  $ProviderElement<StockRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StockRepository create(Ref ref) {
    return stockRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StockRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StockRepository>(value),
    );
  }
}

String _$stockRepositoryHash() => r'7594094aef3ee14dce6b5003c8e752584febb152';
