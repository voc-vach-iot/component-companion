// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CategoryNotifier)
final categoryProvider = CategoryNotifierProvider._();

final class CategoryNotifierProvider
    extends $NotifierProvider<CategoryNotifier, void> {
  CategoryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryNotifierHash();

  @$internal
  @override
  CategoryNotifier create() => CategoryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$categoryNotifierHash() => r'c8072953134ae1e4f3fc0bfd88e9835ca729f2ad';

abstract class _$CategoryNotifier extends $Notifier<void> {
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

@ProviderFor(watchAllCategories)
final watchAllCategoriesProvider = WatchAllCategoriesFamily._();

final class WatchAllCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Category>>,
          List<Category>,
          Stream<List<Category>>
        >
    with $FutureModifier<List<Category>>, $StreamProvider<List<Category>> {
  WatchAllCategoriesProvider._({
    required WatchAllCategoriesFamily super.from,
    required CategorySearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchAllCategoriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchAllCategoriesHash();

  @override
  String toString() {
    return r'watchAllCategoriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Category>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Category>> create(Ref ref) {
    final argument = this.argument as CategorySearchParams;
    return watchAllCategories(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchAllCategoriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchAllCategoriesHash() =>
    r'dd88d77576e0db8a8cefdb2e80de1da3bd3e7a6f';

final class WatchAllCategoriesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<Category>>,
          CategorySearchParams
        > {
  WatchAllCategoriesFamily._()
    : super(
        retry: null,
        name: r'watchAllCategoriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchAllCategoriesProvider call(CategorySearchParams searchParams) =>
      WatchAllCategoriesProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchAllCategoriesProvider';
}

@ProviderFor(watchCategories)
final watchCategoriesProvider = WatchCategoriesFamily._();

final class WatchCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<PageResult<Category>>,
          PageResult<Category>,
          Stream<PageResult<Category>>
        >
    with
        $FutureModifier<PageResult<Category>>,
        $StreamProvider<PageResult<Category>> {
  WatchCategoriesProvider._({
    required WatchCategoriesFamily super.from,
    required CategorySearchParams super.argument,
  }) : super(
         retry: null,
         name: r'watchCategoriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchCategoriesHash();

  @override
  String toString() {
    return r'watchCategoriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<PageResult<Category>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PageResult<Category>> create(Ref ref) {
    final argument = this.argument as CategorySearchParams;
    return watchCategories(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchCategoriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchCategoriesHash() => r'388e97815560ac2d96db0fb557ab8d3271449344';

final class WatchCategoriesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<PageResult<Category>>,
          CategorySearchParams
        > {
  WatchCategoriesFamily._()
    : super(
        retry: null,
        name: r'watchCategoriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchCategoriesProvider call(CategorySearchParams searchParams) =>
      WatchCategoriesProvider._(argument: searchParams, from: this);

  @override
  String toString() => r'watchCategoriesProvider';
}
