// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'component_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ComponentNotifier)
final componentProvider = ComponentNotifierProvider._();

final class ComponentNotifierProvider
    extends $NotifierProvider<ComponentNotifier, void> {
  ComponentNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'componentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$componentNotifierHash();

  @$internal
  @override
  ComponentNotifier create() => ComponentNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$componentNotifierHash() => r'e4863f19225d1d69868071d4daef82ea0920dcac';

abstract class _$ComponentNotifier extends $Notifier<void> {
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

@ProviderFor(watchComponents)
final watchComponentsProvider = WatchComponentsFamily._();

final class WatchComponentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PageResult<Component>>,
          PageResult<Component>,
          Stream<PageResult<Component>>
        >
    with
        $FutureModifier<PageResult<Component>>,
        $StreamProvider<PageResult<Component>> {
  WatchComponentsProvider._({
    required WatchComponentsFamily super.from,
    required ComponentSearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchComponentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchComponentsHash();

  @override
  String toString() {
    return r'watchComponentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<PageResult<Component>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PageResult<Component>> create(Ref ref) {
    final argument = this.argument as ComponentSearchParams;
    return watchComponents(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchComponentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchComponentsHash() => r'e220bde84c96c8a28d8ad899d9da6c53b49e13de';

final class WatchComponentsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<PageResult<Component>>,
          ComponentSearchParams
        > {
  WatchComponentsFamily._()
    : super(
        retry: null,
        name: r'watchComponentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchComponentsProvider call(ComponentSearchParams searchParams) =>
      WatchComponentsProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchComponentsProvider';
}

@ProviderFor(watchAllComponentsGroupedByCategory)
final watchAllComponentsGroupedByCategoryProvider =
    WatchAllComponentsGroupedByCategoryFamily._();

final class WatchAllComponentsGroupedByCategoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<Category, List<Component>>>,
          Map<Category, List<Component>>,
          Stream<Map<Category, List<Component>>>
        >
    with
        $FutureModifier<Map<Category, List<Component>>>,
        $StreamProvider<Map<Category, List<Component>>> {
  WatchAllComponentsGroupedByCategoryProvider._({
    required WatchAllComponentsGroupedByCategoryFamily super.from,
    required ComponentSearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchAllComponentsGroupedByCategoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$watchAllComponentsGroupedByCategoryHash();

  @override
  String toString() {
    return r'watchAllComponentsGroupedByCategoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Map<Category, List<Component>>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<Category, List<Component>>> create(Ref ref) {
    final argument = this.argument as ComponentSearchParams;
    return watchAllComponentsGroupedByCategory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchAllComponentsGroupedByCategoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchAllComponentsGroupedByCategoryHash() =>
    r'637d8faaad58874585e41aea722cc08dc2ca6765';

final class WatchAllComponentsGroupedByCategoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<Map<Category, List<Component>>>,
          ComponentSearchParams
        > {
  WatchAllComponentsGroupedByCategoryFamily._()
    : super(
        retry: null,
        name: r'watchAllComponentsGroupedByCategoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchAllComponentsGroupedByCategoryProvider call(
    ComponentSearchParams searchParams,
  ) => WatchAllComponentsGroupedByCategoryProvider._(
    argument: searchParams,
    from: this,
  );

  @override
  String toString() => r'watchAllComponentsGroupedByCategoryProvider';
}
