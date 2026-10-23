// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'power_supply_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(powerSupplyRepository)
final powerSupplyRepositoryProvider = PowerSupplyRepositoryProvider._();

final class PowerSupplyRepositoryProvider
    extends
        $FunctionalProvider<
          PowerSupplyRepository,
          PowerSupplyRepository,
          PowerSupplyRepository
        >
    with $Provider<PowerSupplyRepository> {
  PowerSupplyRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'powerSupplyRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$powerSupplyRepositoryHash();

  @$internal
  @override
  $ProviderElement<PowerSupplyRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PowerSupplyRepository create(Ref ref) {
    return powerSupplyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PowerSupplyRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PowerSupplyRepository>(value),
    );
  }
}

String _$powerSupplyRepositoryHash() =>
    r'10dc3064ddc961b8cbd23ba0fdd426f18d19682a';
