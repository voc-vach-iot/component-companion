// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variant_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(variantRepository)
final variantRepositoryProvider = VariantRepositoryProvider._();

final class VariantRepositoryProvider
    extends
        $FunctionalProvider<
          VariantRepository,
          VariantRepository,
          VariantRepository
        >
    with $Provider<VariantRepository> {
  VariantRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'variantRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$variantRepositoryHash();

  @$internal
  @override
  $ProviderElement<VariantRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VariantRepository create(Ref ref) {
    return variantRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VariantRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VariantRepository>(value),
    );
  }
}

String _$variantRepositoryHash() => r'1974865b0191f5a7e5352a8b6ff1d2d0688268a6';
