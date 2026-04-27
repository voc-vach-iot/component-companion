// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'component_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(componentRepository)
final componentRepositoryProvider = ComponentRepositoryProvider._();

final class ComponentRepositoryProvider
    extends
        $FunctionalProvider<
          ComponentRepository,
          ComponentRepository,
          ComponentRepository
        >
    with $Provider<ComponentRepository> {
  ComponentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'componentRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$componentRepositoryHash();

  @$internal
  @override
  $ProviderElement<ComponentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ComponentRepository create(Ref ref) {
    return componentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComponentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComponentRepository>(value),
    );
  }
}

String _$componentRepositoryHash() =>
    r'678ec4f2bb374dd8a6c2ab4df9c05c7e34976563';
