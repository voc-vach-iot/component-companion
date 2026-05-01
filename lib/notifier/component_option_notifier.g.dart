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
    r'80bb09cb4ed33f051c4e69ad0c087ce2e117b32b';

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

@ProviderFor(ComponentOptionEventNotifier)
final componentOptionEventProvider = ComponentOptionEventNotifierProvider._();

final class ComponentOptionEventNotifierProvider
    extends $NotifierProvider<ComponentOptionEventNotifier, int> {
  ComponentOptionEventNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'componentOptionEventProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$componentOptionEventNotifierHash();

  @$internal
  @override
  ComponentOptionEventNotifier create() => ComponentOptionEventNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$componentOptionEventNotifierHash() =>
    r'e057d84295cb871378e42f17093757360bce30c8';

abstract class _$ComponentOptionEventNotifier extends $Notifier<int> {
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

@ProviderFor(watchAllComponentOptions)
final watchAllComponentOptionsProvider = WatchAllComponentOptionsFamily._();

final class WatchAllComponentOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComponentOption>>,
          List<ComponentOption>,
          Stream<List<ComponentOption>>
        >
    with
        $FutureModifier<List<ComponentOption>>,
        $StreamProvider<List<ComponentOption>> {
  WatchAllComponentOptionsProvider._({
    required WatchAllComponentOptionsFamily super.from,
    required ComponentOptionSearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchAllComponentOptionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchAllComponentOptionsHash();

  @override
  String toString() {
    return r'watchAllComponentOptionsProvider'
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
    return watchAllComponentOptions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchAllComponentOptionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchAllComponentOptionsHash() =>
    r'1135992cee5bb3526fa804d0a2d2c1790a7f112d';

final class WatchAllComponentOptionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<ComponentOption>>,
          ComponentOptionSearchParams
        > {
  WatchAllComponentOptionsFamily._()
    : super(
        retry: null,
        name: r'watchAllComponentOptionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchAllComponentOptionsProvider call(
    ComponentOptionSearchParams searchParams,
  ) => WatchAllComponentOptionsProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchAllComponentOptionsProvider';
}
