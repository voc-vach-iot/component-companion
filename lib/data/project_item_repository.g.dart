// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_item_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(projectItemRepository)
final projectItemRepositoryProvider = ProjectItemRepositoryProvider._();

final class ProjectItemRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectItemRepository,
          ProjectItemRepository,
          ProjectItemRepository
        >
    with $Provider<ProjectItemRepository> {
  ProjectItemRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectItemRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectItemRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectItemRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectItemRepository create(Ref ref) {
    return projectItemRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectItemRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectItemRepository>(value),
    );
  }
}

String _$projectItemRepositoryHash() =>
    r'7b7d415c093dd41b722783b075fb9e0e5803200a';
