// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'icon_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(iconRepository)
final iconRepositoryProvider = IconRepositoryProvider._();

final class IconRepositoryProvider
    extends $FunctionalProvider<IconRepository, IconRepository, IconRepository>
    with $Provider<IconRepository> {
  IconRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'iconRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$iconRepositoryHash();

  @$internal
  @override
  $ProviderElement<IconRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IconRepository create(Ref ref) {
    return iconRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IconRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IconRepository>(value),
    );
  }
}

String _$iconRepositoryHash() => r'453a9ec8454fe8779bc3831feca24436c85846f5';
