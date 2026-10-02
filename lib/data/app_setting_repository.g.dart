// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_setting_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appSettingRepository)
final appSettingRepositoryProvider = AppSettingRepositoryProvider._();

final class AppSettingRepositoryProvider
    extends
        $FunctionalProvider<
          AppSettingRepository,
          AppSettingRepository,
          AppSettingRepository
        >
    with $Provider<AppSettingRepository> {
  AppSettingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingRepositoryHash();

  @$internal
  @override
  $ProviderElement<AppSettingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppSettingRepository create(Ref ref) {
    return appSettingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettingRepository>(value),
    );
  }
}

String _$appSettingRepositoryHash() =>
    r'c7adb94d7754acdff3e3656107f2735e1b253677';
