// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProjectNotifier)
final projectProvider = ProjectNotifierProvider._();

final class ProjectNotifierProvider
    extends $NotifierProvider<ProjectNotifier, void> {
  ProjectNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectNotifierHash();

  @$internal
  @override
  ProjectNotifier create() => ProjectNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$projectNotifierHash() => r'7570706d570b8f49e4d1176ecfa2c8fb772d89f2';

abstract class _$ProjectNotifier extends $Notifier<void> {
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

@ProviderFor(ProjectEventNotifier)
final projectEventProvider = ProjectEventNotifierProvider._();

final class ProjectEventNotifierProvider
    extends $NotifierProvider<ProjectEventNotifier, int> {
  ProjectEventNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectEventProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectEventNotifierHash();

  @$internal
  @override
  ProjectEventNotifier create() => ProjectEventNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$projectEventNotifierHash() =>
    r'2f0ca6cfe5cb73df1fba6d9935dc4c090d286145';

abstract class _$ProjectEventNotifier extends $Notifier<int> {
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

@ProviderFor(watchProjects)
final watchProjectsProvider = WatchProjectsFamily._();

final class WatchProjectsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PageResult<Project>>,
          PageResult<Project>,
          Stream<PageResult<Project>>
        >
    with
        $FutureModifier<PageResult<Project>>,
        $StreamProvider<PageResult<Project>> {
  WatchProjectsProvider._({
    required WatchProjectsFamily super.from,
    required ProjectSearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchProjectsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchProjectsHash();

  @override
  String toString() {
    return r'watchProjectsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<PageResult<Project>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PageResult<Project>> create(Ref ref) {
    final argument = this.argument as ProjectSearchParams;
    return watchProjects(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchProjectsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchProjectsHash() => r'e0f9fae1632f65230f9ed00e96149761f01ffb78';

final class WatchProjectsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<PageResult<Project>>,
          ProjectSearchParams
        > {
  WatchProjectsFamily._()
    : super(
        retry: null,
        name: r'watchProjectsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchProjectsProvider call(ProjectSearchParams searchParams) =>
      WatchProjectsProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchProjectsProvider';
}

@ProviderFor(watchProjectById)
final watchProjectByIdProvider = WatchProjectByIdFamily._();

final class WatchProjectByIdProvider
    extends
        $FunctionalProvider<AsyncValue<Project?>, Project?, Stream<Project?>>
    with $FutureModifier<Project?>, $StreamProvider<Project?> {
  WatchProjectByIdProvider._({
    required WatchProjectByIdFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'watchProjectByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchProjectByIdHash();

  @override
  String toString() {
    return r'watchProjectByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Project?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Project?> create(Ref ref) {
    final argument = this.argument as int;
    return watchProjectById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchProjectByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchProjectByIdHash() => r'9cb176d7ca804a401f1cd274f20e2130590cec80';

final class WatchProjectByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Project?>, int> {
  WatchProjectByIdFamily._()
    : super(
        retry: null,
        name: r'watchProjectByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchProjectByIdProvider call(int projectId) =>
      WatchProjectByIdProvider._(argument: projectId, from: this);

  @override
  String toString() => r'watchProjectByIdProvider';
}
