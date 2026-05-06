// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_option_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProjectOptionNotifier)
final projectOptionProvider = ProjectOptionNotifierProvider._();

final class ProjectOptionNotifierProvider
    extends $NotifierProvider<ProjectOptionNotifier, void> {
  ProjectOptionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectOptionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectOptionNotifierHash();

  @$internal
  @override
  ProjectOptionNotifier create() => ProjectOptionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$projectOptionNotifierHash() =>
    r'f6d7315368b59601599e1648dbf41b336940a902';

abstract class _$ProjectOptionNotifier extends $Notifier<void> {
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

@ProviderFor(ProjectOptionEventNotifier)
final projectOptionEventProvider = ProjectOptionEventNotifierProvider._();

final class ProjectOptionEventNotifierProvider
    extends $NotifierProvider<ProjectOptionEventNotifier, int> {
  ProjectOptionEventNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectOptionEventProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectOptionEventNotifierHash();

  @$internal
  @override
  ProjectOptionEventNotifier create() => ProjectOptionEventNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$projectOptionEventNotifierHash() =>
    r'5bf52f279ae92576954f69cef2c3ce0dc6ee7d88';

abstract class _$ProjectOptionEventNotifier extends $Notifier<int> {
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

@ProviderFor(watchAllProjectOptions)
final watchAllProjectOptionsProvider = WatchAllProjectOptionsFamily._();

final class WatchAllProjectOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProjectOption>>,
          List<ProjectOption>,
          Stream<List<ProjectOption>>
        >
    with
        $FutureModifier<List<ProjectOption>>,
        $StreamProvider<List<ProjectOption>> {
  WatchAllProjectOptionsProvider._({
    required WatchAllProjectOptionsFamily super.from,
    required ProjectOptionSearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchAllProjectOptionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchAllProjectOptionsHash();

  @override
  String toString() {
    return r'watchAllProjectOptionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ProjectOption>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProjectOption>> create(Ref ref) {
    final argument = this.argument as ProjectOptionSearchParams;
    return watchAllProjectOptions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchAllProjectOptionsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchAllProjectOptionsHash() =>
    r'37e366dfdd3094fc50427f34857c82b4fd04fe17';

final class WatchAllProjectOptionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<ProjectOption>>,
          ProjectOptionSearchParams
        > {
  WatchAllProjectOptionsFamily._()
    : super(
        retry: null,
        name: r'watchAllProjectOptionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchAllProjectOptionsProvider call(ProjectOptionSearchParams searchParams) =>
      WatchAllProjectOptionsProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchAllProjectOptionsProvider';
}
