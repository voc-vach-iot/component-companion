// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_options_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tuỳ chọn tìm kiếm dùng chung cho mọi ô tìm kiếm, được lưu lại giữa các lần mở app.

@ProviderFor(SearchOptionsNotifier)
final searchOptionsProvider = SearchOptionsNotifierProvider._();

/// Tuỳ chọn tìm kiếm dùng chung cho mọi ô tìm kiếm, được lưu lại giữa các lần mở app.
final class SearchOptionsNotifierProvider
    extends $NotifierProvider<SearchOptionsNotifier, SearchOptions> {
  /// Tuỳ chọn tìm kiếm dùng chung cho mọi ô tìm kiếm, được lưu lại giữa các lần mở app.
  SearchOptionsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchOptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchOptionsNotifierHash();

  @$internal
  @override
  SearchOptionsNotifier create() => SearchOptionsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchOptions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchOptions>(value),
    );
  }
}

String _$searchOptionsNotifierHash() =>
    r'78efe83a708d7a7e4440764f76246b61122d1a0e';

/// Tuỳ chọn tìm kiếm dùng chung cho mọi ô tìm kiếm, được lưu lại giữa các lần mở app.

abstract class _$SearchOptionsNotifier extends $Notifier<SearchOptions> {
  SearchOptions build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SearchOptions, SearchOptions>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SearchOptions, SearchOptions>,
              SearchOptions,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
