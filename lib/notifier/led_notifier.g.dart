// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'led_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Yêu cầu trang Kho mở tab sơ đồ của 1 kho (VD bấm "Xem kho" sau khi tìm).
/// [token] tăng mỗi lần yêu cầu để bấm lại cùng kho vẫn có tác dụng.

@ProviderFor(StorageFocus)
final storageFocusProvider = StorageFocusProvider._();

/// Yêu cầu trang Kho mở tab sơ đồ của 1 kho (VD bấm "Xem kho" sau khi tìm).
/// [token] tăng mỗi lần yêu cầu để bấm lại cùng kho vẫn có tác dụng.
final class StorageFocusProvider
    extends $NotifierProvider<StorageFocus, ({int storageId, int token})?> {
  /// Yêu cầu trang Kho mở tab sơ đồ của 1 kho (VD bấm "Xem kho" sau khi tìm).
  /// [token] tăng mỗi lần yêu cầu để bấm lại cùng kho vẫn có tác dụng.
  StorageFocusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageFocusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageFocusHash();

  @$internal
  @override
  StorageFocus create() => StorageFocus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({int storageId, int token})? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({int storageId, int token})?>(
        value,
      ),
    );
  }
}

String _$storageFocusHash() => r'31359c13f4629c6827a33e8796565ff267b1d80b';

/// Yêu cầu trang Kho mở tab sơ đồ của 1 kho (VD bấm "Xem kho" sau khi tìm).
/// [token] tăng mỗi lần yêu cầu để bấm lại cùng kho vẫn có tác dụng.

abstract class _$StorageFocus extends $Notifier<({int storageId, int token})?> {
  ({int storageId, int token})? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({int storageId, int token})?,
              ({int storageId, int token})?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({int storageId, int token})?,
                ({int storageId, int token})?
              >,
              ({int storageId, int token})?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Bộ điều khiển LED theo thiết bị BLE đã ghép ([deviceId] rỗng = giả lập).

@ProviderFor(ledController)
final ledControllerProvider = LedControllerFamily._();

/// Bộ điều khiển LED theo thiết bị BLE đã ghép ([deviceId] rỗng = giả lập).

final class LedControllerProvider
    extends $FunctionalProvider<LedController, LedController, LedController>
    with $Provider<LedController> {
  /// Bộ điều khiển LED theo thiết bị BLE đã ghép ([deviceId] rỗng = giả lập).
  LedControllerProvider._({
    required LedControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ledControllerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ledControllerHash();

  @override
  String toString() {
    return r'ledControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<LedController> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LedController create(Ref ref) {
    final argument = this.argument as String;
    return ledController(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LedController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LedController>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LedControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ledControllerHash() => r'c7b0f27a8e02e6410f0ae20f771879630d23b8c7';

/// Bộ điều khiển LED theo thiết bị BLE đã ghép ([deviceId] rỗng = giả lập).

final class LedControllerFamily extends $Family
    with $FunctionalFamilyOverride<LedController, String> {
  LedControllerFamily._()
    : super(
        retry: null,
        name: r'ledControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Bộ điều khiển LED theo thiết bị BLE đã ghép ([deviceId] rỗng = giả lập).

  LedControllerProvider call(String deviceId) =>
      LedControllerProvider._(argument: deviceId, from: this);

  @override
  String toString() => r'ledControllerProvider';
}

/// Các kho đang sáng LED: storageId -> phiên sáng. Tự xoá khi hết giờ.

@ProviderFor(LedSessions)
final ledSessionsProvider = LedSessionsProvider._();

/// Các kho đang sáng LED: storageId -> phiên sáng. Tự xoá khi hết giờ.
final class LedSessionsProvider
    extends $NotifierProvider<LedSessions, Map<int, LightSession>> {
  /// Các kho đang sáng LED: storageId -> phiên sáng. Tự xoá khi hết giờ.
  LedSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ledSessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ledSessionsHash();

  @$internal
  @override
  LedSessions create() => LedSessions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, LightSession> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, LightSession>>(value),
    );
  }
}

String _$ledSessionsHash() => r'6aa93dba3cbc1e525ccb1077626ee56ba5b54b6a';

/// Các kho đang sáng LED: storageId -> phiên sáng. Tự xoá khi hết giờ.

abstract class _$LedSessions extends $Notifier<Map<int, LightSession>> {
  Map<int, LightSession> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<Map<int, LightSession>, Map<int, LightSession>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<int, LightSession>, Map<int, LightSession>>,
              Map<int, LightSession>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
