// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shop_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ShopNotifier)
final shopProvider = ShopNotifierProvider._();

final class ShopNotifierProvider extends $NotifierProvider<ShopNotifier, void> {
  ShopNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shopProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shopNotifierHash();

  @$internal
  @override
  ShopNotifier create() => ShopNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$shopNotifierHash() => r'1f8ad6dfa61849570b8d89c59ee2b70db9035055';

abstract class _$ShopNotifier extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(watchAllShops)
final watchAllShopsProvider = WatchAllShopsFamily._();

final class WatchAllShopsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Shop>>,
          List<Shop>,
          Stream<List<Shop>>
        >
    with $FutureModifier<List<Shop>>, $StreamProvider<List<Shop>> {
  WatchAllShopsProvider._({
    required WatchAllShopsFamily super.from,
    required ({String name, SearchOptions searchOptions}) super.argument,
  }) : super(
         retry: null,
         name: r'watchAllShopsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchAllShopsHash();

  @override
  String toString() {
    return r'watchAllShopsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<Shop>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Shop>> create(Ref ref) {
    final argument =
        this.argument as ({String name, SearchOptions searchOptions});
    return watchAllShops(
      ref,
      name: argument.name,
      searchOptions: argument.searchOptions,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WatchAllShopsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchAllShopsHash() => r'77d1b14039a9c86e3e299c79178b771e5310c973';

final class WatchAllShopsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<Shop>>,
          ({String name, SearchOptions searchOptions})
        > {
  WatchAllShopsFamily._()
    : super(
        retry: null,
        name: r'watchAllShopsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchAllShopsProvider call({
    String name = '',
    SearchOptions searchOptions = const SearchOptions(),
  }) => WatchAllShopsProvider._(
    argument: (name: name, searchOptions: searchOptions),
    from: this,
  );

  @override
  String toString() => r'watchAllShopsProvider';
}
