// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(watchDashboard)
final watchDashboardProvider = WatchDashboardProvider._();

final class WatchDashboardProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardData>,
          DashboardData,
          Stream<DashboardData>
        >
    with $FutureModifier<DashboardData>, $StreamProvider<DashboardData> {
  WatchDashboardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchDashboardProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchDashboardHash();

  @$internal
  @override
  $StreamProviderElement<DashboardData> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DashboardData> create(Ref ref) {
    return watchDashboard(ref);
  }
}

String _$watchDashboardHash() => r'1580ba9d247a8c64b878272c2d6075316dede47a';
