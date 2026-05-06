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

@ProviderFor(ComponentEventNotifier)
final componentEventProvider = ComponentEventNotifierProvider._();

final class ComponentEventNotifierProvider
    extends $NotifierProvider<ComponentEventNotifier, int> {
  ComponentEventNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'componentEventProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$componentEventNotifierHash();

  @$internal
  @override
  ComponentEventNotifier create() => ComponentEventNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$componentEventNotifierHash() =>
    r'21919efac1c3c8b683805d2545dc0171e11fde11';

abstract class _$ComponentEventNotifier extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(watchAllComponents)
final watchAllComponentsProvider = WatchAllComponentsFamily._();

final class WatchAllComponentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Component>>,
          List<Component>,
          Stream<List<Component>>
        >
    with $FutureModifier<List<Component>>, $StreamProvider<List<Component>> {
  WatchAllComponentsProvider._({
    required WatchAllComponentsFamily super.from,
    required ComponentSearchParams? super.argument,
  }) : super(
         retry: null,
         name: r'watchAllComponentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchAllComponentsHash();

  @override
  String toString() {
    return r'watchAllComponentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Component>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Component>> create(Ref ref) {
    final argument = this.argument as ComponentSearchParams?;
    return watchAllComponents(ref, searchParams: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchAllComponentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchAllComponentsHash() =>
    r'da326543fdfbfbf348ce469dcad414fd1c9dedb1';

final class WatchAllComponentsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<Component>>,
          ComponentSearchParams?
        > {
  WatchAllComponentsFamily._()
    : super(
        retry: null,
        name: r'watchAllComponentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchAllComponentsProvider call({ComponentSearchParams? searchParams}) =>
      WatchAllComponentsProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchAllComponentsProvider';
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

String _$watchComponentsHash() => r'1cf6a6c570ccf642519f9385c305f3fbaa092b7c';

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
    r'e48609c463fbac452e034c1fbe8493aa59b987f9';

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
