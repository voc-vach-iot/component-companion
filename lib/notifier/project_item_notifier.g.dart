// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_item_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProjectItemNotifier)
final projectItemProvider = ProjectItemNotifierProvider._();

final class ProjectItemNotifierProvider
    extends $NotifierProvider<ProjectItemNotifier, void> {
  ProjectItemNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectItemProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectItemNotifierHash();

  @$internal
  @override
  ProjectItemNotifier create() => ProjectItemNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$projectItemNotifierHash() =>
    r'c360f18ac4c8b7345ea0eac0013adbf016fa978e';

abstract class _$ProjectItemNotifier extends $Notifier<void> {
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

@ProviderFor(ProjectItemEventNotifier)
final projectItemEventProvider = ProjectItemEventNotifierProvider._();

final class ProjectItemEventNotifierProvider
    extends $NotifierProvider<ProjectItemEventNotifier, int> {
  ProjectItemEventNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectItemEventProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectItemEventNotifierHash();

  @$internal
  @override
  ProjectItemEventNotifier create() => ProjectItemEventNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$projectItemEventNotifierHash() =>
    r'11623edddce2b37ff0f9c0824565f86123f5f50c';

abstract class _$ProjectItemEventNotifier extends $Notifier<int> {
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

@ProviderFor(watchAllProjectItems)
final watchAllProjectItemsProvider = WatchAllProjectItemsFamily._();

final class WatchAllProjectItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProjectItem>>,
          List<ProjectItem>,
          Stream<List<ProjectItem>>
        >
    with
        $FutureModifier<List<ProjectItem>>,
        $StreamProvider<List<ProjectItem>> {
  WatchAllProjectItemsProvider._({
    required WatchAllProjectItemsFamily super.from,
    required ProjectItemSearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchAllProjectItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchAllProjectItemsHash();

  @override
  String toString() {
    return r'watchAllProjectItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ProjectItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProjectItem>> create(Ref ref) {
    final argument = this.argument as ProjectItemSearchParams;
    return watchAllProjectItems(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchAllProjectItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchAllProjectItemsHash() =>
    r'4508f8ca4579a52cbadafa6b8958f4a53468f5ee';

final class WatchAllProjectItemsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<ProjectItem>>,
          ProjectItemSearchParams
        > {
  WatchAllProjectItemsFamily._()
    : super(
        retry: null,
        name: r'watchAllProjectItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchAllProjectItemsProvider call(ProjectItemSearchParams searchParams) =>
      WatchAllProjectItemsProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchAllProjectItemsProvider';
}
