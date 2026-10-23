// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(watchAllStorages)
final watchAllStoragesProvider = WatchAllStoragesProvider._();

final class WatchAllStoragesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Storage>>,
          List<Storage>,
          Stream<List<Storage>>
        >
    with $FutureModifier<List<Storage>>, $StreamProvider<List<Storage>> {
  WatchAllStoragesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchAllStoragesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchAllStoragesHash();

  @$internal
  @override
  $StreamProviderElement<List<Storage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Storage>> create(Ref ref) {
    return watchAllStorages(ref);
  }
}

String _$watchAllStoragesHash() => r'2254a38fbc964ac4a50d1121b96d4205e396a6ec';

@ProviderFor(watchStorageTrays)
final watchStorageTraysProvider = WatchStorageTraysFamily._();

final class WatchStorageTraysProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StorageTray>>,
          List<StorageTray>,
          Stream<List<StorageTray>>
        >
    with
        $FutureModifier<List<StorageTray>>,
        $StreamProvider<List<StorageTray>> {
  WatchStorageTraysProvider._({
    required WatchStorageTraysFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'watchStorageTraysProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchStorageTraysHash();

  @override
  String toString() {
    return r'watchStorageTraysProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<StorageTray>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StorageTray>> create(Ref ref) {
    final argument = this.argument as int;
    return watchStorageTrays(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchStorageTraysProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchStorageTraysHash() => r'a3df55d2d26936e1b0c294d2eb962921a6edb1ed';

final class WatchStorageTraysFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<StorageTray>>, int> {
  WatchStorageTraysFamily._()
    : super(
        retry: null,
        name: r'watchStorageTraysProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchStorageTraysProvider call(int storageId) =>
      WatchStorageTraysProvider._(argument: storageId, from: this);

  @override
  String toString() => r'watchStorageTraysProvider';
}

@ProviderFor(watchAllTrayTypes)
final watchAllTrayTypesProvider = WatchAllTrayTypesProvider._();

final class WatchAllTrayTypesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TrayType>>,
          List<TrayType>,
          Stream<List<TrayType>>
        >
    with $FutureModifier<List<TrayType>>, $StreamProvider<List<TrayType>> {
  WatchAllTrayTypesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchAllTrayTypesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchAllTrayTypesHash();

  @$internal
  @override
  $StreamProviderElement<List<TrayType>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TrayType>> create(Ref ref) {
    return watchAllTrayTypes(ref);
  }
}

String _$watchAllTrayTypesHash() => r'b29787694ace6c9e22c7a8c2a4186cd03a9f2227';

@ProviderFor(watchAllPowerSupplies)
final watchAllPowerSuppliesProvider = WatchAllPowerSuppliesProvider._();

final class WatchAllPowerSuppliesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PowerSupply>>,
          List<PowerSupply>,
          Stream<List<PowerSupply>>
        >
    with
        $FutureModifier<List<PowerSupply>>,
        $StreamProvider<List<PowerSupply>> {
  WatchAllPowerSuppliesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchAllPowerSuppliesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchAllPowerSuppliesHash();

  @$internal
  @override
  $StreamProviderElement<List<PowerSupply>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<PowerSupply>> create(Ref ref) {
    return watchAllPowerSupplies(ref);
  }
}

String _$watchAllPowerSuppliesHash() =>
    r'0f754b3065b895ff049c41981bc97749323c34b5';

@ProviderFor(watchUnplacedVariants)
final watchUnplacedVariantsProvider = WatchUnplacedVariantsProvider._();

final class WatchUnplacedVariantsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComponentVariant>>,
          List<ComponentVariant>,
          Stream<List<ComponentVariant>>
        >
    with
        $FutureModifier<List<ComponentVariant>>,
        $StreamProvider<List<ComponentVariant>> {
  WatchUnplacedVariantsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchUnplacedVariantsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchUnplacedVariantsHash();

  @$internal
  @override
  $StreamProviderElement<List<ComponentVariant>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ComponentVariant>> create(Ref ref) {
    return watchUnplacedVariants(ref);
  }
}

String _$watchUnplacedVariantsHash() =>
    r'04a9ed4053837b5a6e662025aa707758531f913d';
