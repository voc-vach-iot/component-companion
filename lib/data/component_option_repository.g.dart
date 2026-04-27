// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'component_option_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(componentOptionRepository)
final componentOptionRepositoryProvider = ComponentOptionRepositoryProvider._();

final class ComponentOptionRepositoryProvider
    extends
        $FunctionalProvider<
          ComponentOptionRepository,
          ComponentOptionRepository,
          ComponentOptionRepository
        >
    with $Provider<ComponentOptionRepository> {
  ComponentOptionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'componentOptionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$componentOptionRepositoryHash();

  @$internal
  @override
  $ProviderElement<ComponentOptionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ComponentOptionRepository create(Ref ref) {
    return componentOptionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComponentOptionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComponentOptionRepository>(value),
    );
  }
}

String _$componentOptionRepositoryHash() =>
    r'2f6180c9f42c41d90f2a956a49b789cff1086a3b';
