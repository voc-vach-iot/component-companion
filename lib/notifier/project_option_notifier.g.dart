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
    r'6967d7163e77da74e237bf90094c077ccf5b7344';

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
