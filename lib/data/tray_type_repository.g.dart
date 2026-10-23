// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tray_type_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trayTypeRepository)
final trayTypeRepositoryProvider = TrayTypeRepositoryProvider._();

final class TrayTypeRepositoryProvider
    extends
        $FunctionalProvider<
          TrayTypeRepository,
          TrayTypeRepository,
          TrayTypeRepository
        >
    with $Provider<TrayTypeRepository> {
  TrayTypeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trayTypeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trayTypeRepositoryHash();

  @$internal
  @override
  $ProviderElement<TrayTypeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrayTypeRepository create(Ref ref) {
    return trayTypeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrayTypeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrayTypeRepository>(value),
    );
  }
}

String _$trayTypeRepositoryHash() =>
    r'6054283351fd4355a24386bd2409614110ff510f';
