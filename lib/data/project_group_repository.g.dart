// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_group_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(projectGroupRepository)
final projectGroupRepositoryProvider = ProjectGroupRepositoryProvider._();

final class ProjectGroupRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectGroupRepository,
          ProjectGroupRepository,
          ProjectGroupRepository
        >
    with $Provider<ProjectGroupRepository> {
  ProjectGroupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectGroupRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectGroupRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectGroupRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectGroupRepository create(Ref ref) {
    return projectGroupRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectGroupRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectGroupRepository>(value),
    );
  }
}

String _$projectGroupRepositoryHash() =>
    r'05b27a568fae1bfb28044993667026cd965361d2';
