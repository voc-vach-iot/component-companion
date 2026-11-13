// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_undo_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Ngăn xếp hoàn tác các thao tác sơ đồ kho (đánh số LED, dời LED, chuyển
/// ngăn), tách theo kho, tối đa [maxSteps] bước. State là số bước hiện có
/// của mỗi kho để widget rebuild khi đổi.

@ProviderFor(StorageUndo)
final storageUndoProvider = StorageUndoProvider._();

/// Ngăn xếp hoàn tác các thao tác sơ đồ kho (đánh số LED, dời LED, chuyển
/// ngăn), tách theo kho, tối đa [maxSteps] bước. State là số bước hiện có
/// của mỗi kho để widget rebuild khi đổi.
final class StorageUndoProvider
    extends $NotifierProvider<StorageUndo, Map<int, int>> {
  /// Ngăn xếp hoàn tác các thao tác sơ đồ kho (đánh số LED, dời LED, chuyển
  /// ngăn), tách theo kho, tối đa [maxSteps] bước. State là số bước hiện có
  /// của mỗi kho để widget rebuild khi đổi.
  StorageUndoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageUndoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageUndoHash();

  @$internal
  @override
  StorageUndo create() => StorageUndo();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, int>>(value),
    );
  }
}

String _$storageUndoHash() => r'ecad963c430c0b07715921255b1119dac28ff9c3';

/// Ngăn xếp hoàn tác các thao tác sơ đồ kho (đánh số LED, dời LED, chuyển
/// ngăn), tách theo kho, tối đa [maxSteps] bước. State là số bước hiện có
/// của mỗi kho để widget rebuild khi đổi.

abstract class _$StorageUndo extends $Notifier<Map<int, int>> {
  Map<int, int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Map<int, int>, Map<int, int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<int, int>, Map<int, int>>,
              Map<int, int>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
