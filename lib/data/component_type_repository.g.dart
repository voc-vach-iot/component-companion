// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'component_type_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(componentTypeRepository)
final componentTypeRepositoryProvider = ComponentTypeRepositoryProvider._();

final class ComponentTypeRepositoryProvider
    extends
        $FunctionalProvider<
          ComponentTypeRepository,
          ComponentTypeRepository,
          ComponentTypeRepository
        >
    with $Provider<ComponentTypeRepository> {
  ComponentTypeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'componentTypeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$componentTypeRepositoryHash();

  @$internal
  @override
  $ProviderElement<ComponentTypeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ComponentTypeRepository create(Ref ref) {
    return componentTypeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComponentTypeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComponentTypeRepository>(value),
    );
  }
}

String _$componentTypeRepositoryHash() =>
    r'8fea36dbeba7130b82f249d464d484633dd57a6a';
