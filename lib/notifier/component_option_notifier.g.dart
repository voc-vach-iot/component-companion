// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'component_option_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ComponentOptionNotifier)
final componentOptionProvider = ComponentOptionNotifierProvider._();

final class ComponentOptionNotifierProvider
    extends $NotifierProvider<ComponentOptionNotifier, void> {
  ComponentOptionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'componentOptionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$componentOptionNotifierHash();

  @$internal
  @override
  ComponentOptionNotifier create() => ComponentOptionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$componentOptionNotifierHash() =>
    r'383654d541c17634252ec44fea1f3a4724020eee';

abstract class _$ComponentOptionNotifier extends $Notifier<void> {
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

@ProviderFor(watchComponentOptions)
final watchComponentOptionsProvider = WatchComponentOptionsFamily._();

final class WatchComponentOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComponentOption>>,
          List<ComponentOption>,
          Stream<List<ComponentOption>>
        >
    with
        $FutureModifier<List<ComponentOption>>,
        $StreamProvider<List<ComponentOption>> {
  WatchComponentOptionsProvider._({
    required WatchComponentOptionsFamily super.from,
    required ComponentOptionSearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchComponentOptionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchComponentOptionsHash();

  @override
  String toString() {
    return r'watchComponentOptionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ComponentOption>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ComponentOption>> create(Ref ref) {
    final argument = this.argument as ComponentOptionSearchParams;
    return watchComponentOptions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchComponentOptionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchComponentOptionsHash() =>
    r'8776434e3fdad76cbdb3a402481aa044b23cc29d';

final class WatchComponentOptionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<ComponentOption>>,
          ComponentOptionSearchParams
        > {
  WatchComponentOptionsFamily._()
    : super(
        retry: null,
        name: r'watchComponentOptionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchComponentOptionsProvider call(
    ComponentOptionSearchParams searchParams,
  ) => WatchComponentOptionsProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchComponentOptionsProvider';
}
