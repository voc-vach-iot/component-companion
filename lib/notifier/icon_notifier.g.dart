// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'icon_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(watchIcons)
final watchIconsProvider = WatchIconsProvider._();

final class WatchIconsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<IconAsset>>,
          List<IconAsset>,
          Stream<List<IconAsset>>
        >
    with $FutureModifier<List<IconAsset>>, $StreamProvider<List<IconAsset>> {
  WatchIconsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchIconsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchIconsHash();

  @$internal
  @override
  $StreamProviderElement<List<IconAsset>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<IconAsset>> create(Ref ref) {
    return watchIcons(ref);
  }
}

String _$watchIconsHash() => r'1f349af05b037a67606e02ffaea3109481295bcd';
