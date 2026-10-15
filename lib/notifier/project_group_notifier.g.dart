// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_group_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProjectGroupNotifier)
final projectGroupProvider = ProjectGroupNotifierProvider._();

final class ProjectGroupNotifierProvider
    extends $NotifierProvider<ProjectGroupNotifier, void> {
  ProjectGroupNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectGroupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectGroupNotifierHash();

  @$internal
  @override
  ProjectGroupNotifier create() => ProjectGroupNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$projectGroupNotifierHash() =>
    r'b3f951f3562a10e08867adb06e42638c52b9d780';

abstract class _$ProjectGroupNotifier extends $Notifier<void> {
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

@ProviderFor(watchProjectGroups)
final watchProjectGroupsProvider = WatchProjectGroupsFamily._();

final class WatchProjectGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProjectGroup>>,
          List<ProjectGroup>,
          Stream<List<ProjectGroup>>
        >
    with
        $FutureModifier<List<ProjectGroup>>,
        $StreamProvider<List<ProjectGroup>> {
  WatchProjectGroupsProvider._({
    required WatchProjectGroupsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'watchProjectGroupsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchProjectGroupsHash();

  @override
  String toString() {
    return r'watchProjectGroupsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ProjectGroup>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProjectGroup>> create(Ref ref) {
    final argument = this.argument as int;
    return watchProjectGroups(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchProjectGroupsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchProjectGroupsHash() =>
    r'9d73c9e210d561db0d127057696fde52c7e51991';

final class WatchProjectGroupsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ProjectGroup>>, int> {
  WatchProjectGroupsFamily._()
    : super(
        retry: null,
        name: r'watchProjectGroupsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchProjectGroupsProvider call(int projectId) =>
      WatchProjectGroupsProvider._(argument: projectId, from: this);

  @override
  String toString() => r'watchProjectGroupsProvider';
}
