// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'component_type_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ComponentTypeNotifier)
final componentTypeProvider = ComponentTypeNotifierProvider._();

final class ComponentTypeNotifierProvider
    extends $NotifierProvider<ComponentTypeNotifier, void> {
  ComponentTypeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'componentTypeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$componentTypeNotifierHash();

  @$internal
  @override
  ComponentTypeNotifier create() => ComponentTypeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$componentTypeNotifierHash() =>
    r'7b0890f1338d193ba321ddb69e686a654c1f6b80';

abstract class _$ComponentTypeNotifier extends $Notifier<void> {
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

@ProviderFor(watchAllComponentTypes)
final watchAllComponentTypesProvider = WatchAllComponentTypesFamily._();

final class WatchAllComponentTypesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComponentType>>,
          List<ComponentType>,
          Stream<List<ComponentType>>
        >
    with
        $FutureModifier<List<ComponentType>>,
        $StreamProvider<List<ComponentType>> {
  WatchAllComponentTypesProvider._({
    required WatchAllComponentTypesFamily super.from,
    required ComponentTypeSearchParams? super.argument,
  }) : super(
         retry: null,
         name: r'watchAllComponentTypesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchAllComponentTypesHash();

  @override
  String toString() {
    return r'watchAllComponentTypesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ComponentType>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ComponentType>> create(Ref ref) {
    final argument = this.argument as ComponentTypeSearchParams?;
    return watchAllComponentTypes(ref, searchParams: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchAllComponentTypesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchAllComponentTypesHash() =>
    r'7dcdf9457375f863ee1df64361ef25a2f7002d08';

final class WatchAllComponentTypesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<ComponentType>>,
          ComponentTypeSearchParams?
        > {
  WatchAllComponentTypesFamily._()
    : super(
        retry: null,
        name: r'watchAllComponentTypesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchAllComponentTypesProvider call({
    ComponentTypeSearchParams? searchParams,
  }) => WatchAllComponentTypesProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchAllComponentTypesProvider';
}

@ProviderFor(watchComponentTypes)
final watchComponentTypesProvider = WatchComponentTypesFamily._();

final class WatchComponentTypesProvider
    extends
        $FunctionalProvider<
          AsyncValue<PageResult<ComponentType>>,
          PageResult<ComponentType>,
          Stream<PageResult<ComponentType>>
        >
    with
        $FutureModifier<PageResult<ComponentType>>,
        $StreamProvider<PageResult<ComponentType>> {
  WatchComponentTypesProvider._({
    required WatchComponentTypesFamily super.from,
    required ComponentTypeSearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchComponentTypesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchComponentTypesHash();

  @override
  String toString() {
    return r'watchComponentTypesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<PageResult<ComponentType>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PageResult<ComponentType>> create(Ref ref) {
    final argument = this.argument as ComponentTypeSearchParams;
    return watchComponentTypes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchComponentTypesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchComponentTypesHash() =>
    r'cc80fa5b6c42e34f6c1458d82c56aa8f99ef5e74';

final class WatchComponentTypesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<PageResult<ComponentType>>,
          ComponentTypeSearchParams
        > {
  WatchComponentTypesFamily._()
    : super(
        retry: null,
        name: r'watchComponentTypesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchComponentTypesProvider call(ComponentTypeSearchParams searchParams) =>
      WatchComponentTypesProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchComponentTypesProvider';
}
