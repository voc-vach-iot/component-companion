// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variant_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VariantNotifier)
final variantProvider = VariantNotifierProvider._();

final class VariantNotifierProvider
    extends $NotifierProvider<VariantNotifier, void> {
  VariantNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'variantProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$variantNotifierHash();

  @$internal
  @override
  VariantNotifier create() => VariantNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$variantNotifierHash() => r'8c8ee494ebcc16bab5a558eeddb8525ac00b3b49';

abstract class _$VariantNotifier extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(watchVariantsOfComponent)
final watchVariantsOfComponentProvider = WatchVariantsOfComponentFamily._();

final class WatchVariantsOfComponentProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComponentVariant>>,
          List<ComponentVariant>,
          Stream<List<ComponentVariant>>
        >
    with
        $FutureModifier<List<ComponentVariant>>,
        $StreamProvider<List<ComponentVariant>> {
  WatchVariantsOfComponentProvider._({
    required WatchVariantsOfComponentFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'watchVariantsOfComponentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchVariantsOfComponentHash();

  @override
  String toString() {
    return r'watchVariantsOfComponentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ComponentVariant>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ComponentVariant>> create(Ref ref) {
    final argument = this.argument as int;
    return watchVariantsOfComponent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchVariantsOfComponentProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchVariantsOfComponentHash() =>
    r'4e740f902f05324ae22393f271accd605102c675';

final class WatchVariantsOfComponentFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ComponentVariant>>, int> {
  WatchVariantsOfComponentFamily._()
    : super(
        retry: null,
        name: r'watchVariantsOfComponentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchVariantsOfComponentProvider call(int componentId) =>
      WatchVariantsOfComponentProvider._(argument: componentId, from: this);

  @override
  String toString() => r'watchVariantsOfComponentProvider';
}

/// Biến thể có hàng đang về (đã đặt, chưa nhận).

@ProviderFor(watchIncomingVariants)
final watchIncomingVariantsProvider = WatchIncomingVariantsProvider._();

/// Biến thể có hàng đang về (đã đặt, chưa nhận).

final class WatchIncomingVariantsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComponentVariant>>,
          List<ComponentVariant>,
          Stream<List<ComponentVariant>>
        >
    with
        $FutureModifier<List<ComponentVariant>>,
        $StreamProvider<List<ComponentVariant>> {
  /// Biến thể có hàng đang về (đã đặt, chưa nhận).
  WatchIncomingVariantsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchIncomingVariantsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchIncomingVariantsHash();

  @$internal
  @override
  $StreamProviderElement<List<ComponentVariant>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ComponentVariant>> create(Ref ref) {
    return watchIncomingVariants(ref);
  }
}

String _$watchIncomingVariantsHash() =>
    r'dff40aed65bce7e91043b0c550fb8fabd36ece7d';

/// Nhật ký kho của 1 biến thể (null = toàn bộ), mới nhất trước.

@ProviderFor(watchStockLogs)
final watchStockLogsProvider = WatchStockLogsFamily._();

/// Nhật ký kho của 1 biến thể (null = toàn bộ), mới nhất trước.

final class WatchStockLogsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StockLog>>,
          List<StockLog>,
          Stream<List<StockLog>>
        >
    with $FutureModifier<List<StockLog>>, $StreamProvider<List<StockLog>> {
  /// Nhật ký kho của 1 biến thể (null = toàn bộ), mới nhất trước.
  WatchStockLogsProvider._({
    required WatchStockLogsFamily super.from,
    required ({int? variantId, int limit}) super.argument,
  }) : super(
         retry: null,
         name: r'watchStockLogsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchStockLogsHash();

  @override
  String toString() {
    return r'watchStockLogsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<StockLog>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StockLog>> create(Ref ref) {
    final argument = this.argument as ({int? variantId, int limit});
    return watchStockLogs(
      ref,
      variantId: argument.variantId,
      limit: argument.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WatchStockLogsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchStockLogsHash() => r'48bb3d187850de36129b4290ab3b625bebb3f31c';

/// Nhật ký kho của 1 biến thể (null = toàn bộ), mới nhất trước.

final class WatchStockLogsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<StockLog>>,
          ({int? variantId, int limit})
        > {
  WatchStockLogsFamily._()
    : super(
        retry: null,
        name: r'watchStockLogsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Nhật ký kho của 1 biến thể (null = toàn bộ), mới nhất trước.

  WatchStockLogsProvider call({int? variantId, int limit = 0}) =>
      WatchStockLogsProvider._(
        argument: (variantId: variantId, limit: limit),
        from: this,
      );

  @override
  String toString() => r'watchStockLogsProvider';
}
