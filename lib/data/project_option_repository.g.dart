// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_option_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(projectOptionRepository)
final projectOptionRepositoryProvider = ProjectOptionRepositoryProvider._();

final class ProjectOptionRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectOptionRepository,
          ProjectOptionRepository,
          ProjectOptionRepository
        >
    with $Provider<ProjectOptionRepository> {
  ProjectOptionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectOptionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectOptionRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectOptionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectOptionRepository create(Ref ref) {
    return projectOptionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectOptionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectOptionRepository>(value),
    );
  }
}

String _$projectOptionRepositoryHash() =>
    r'e25a2f7a36166a567e6275a46e2aecdba5aca098';
