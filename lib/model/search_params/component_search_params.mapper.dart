// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'component_search_params.dart';

class StockFilterMapper extends EnumMapper<StockFilter> {
  StockFilterMapper._();

  static StockFilterMapper? _instance;
  static StockFilterMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = StockFilterMapper._());
    }
    return _instance!;
  }

  static StockFilter fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  StockFilter decode(dynamic value) {
    switch (value) {
      case r'all':
        return StockFilter.all;
      case r'inStock':
        return StockFilter.inStock;
      case r'low':
        return StockFilter.low;
      case r'out':
        return StockFilter.out;
      case r'untracked':
        return StockFilter.untracked;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(StockFilter self) {
    switch (self) {
      case StockFilter.all:
        return r'all';
      case StockFilter.inStock:
        return r'inStock';
      case StockFilter.low:
        return r'low';
      case StockFilter.out:
        return r'out';
      case StockFilter.untracked:
        return r'untracked';
    }
  }
}

extension StockFilterMapperExtension on StockFilter {
  String toValue() {
    StockFilterMapper.ensureInitialized();
    return MapperContainer.globals.toValue<StockFilter>(this) as String;
  }
}

class ComponentSortMapper extends EnumMapper<ComponentSort> {
  ComponentSortMapper._();

  static ComponentSortMapper? _instance;
  static ComponentSortMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ComponentSortMapper._());
    }
    return _instance!;
  }

  static ComponentSort fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ComponentSort decode(dynamic value) {
    switch (value) {
      case r'added':
        return ComponentSort.added;
      case r'newest':
        return ComponentSort.newest;
      case r'nameAsc':
        return ComponentSort.nameAsc;
      case r'category':
        return ComponentSort.category;
      case r'priceAsc':
        return ComponentSort.priceAsc;
      case r'priceDesc':
        return ComponentSort.priceDesc;
      case r'stockAsc':
        return ComponentSort.stockAsc;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ComponentSort self) {
    switch (self) {
      case ComponentSort.added:
        return r'added';
      case ComponentSort.newest:
        return r'newest';
      case ComponentSort.nameAsc:
        return r'nameAsc';
      case ComponentSort.category:
        return r'category';
      case ComponentSort.priceAsc:
        return r'priceAsc';
      case ComponentSort.priceDesc:
        return r'priceDesc';
      case ComponentSort.stockAsc:
        return r'stockAsc';
    }
  }
}

extension ComponentSortMapperExtension on ComponentSort {
  String toValue() {
    ComponentSortMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ComponentSort>(this) as String;
  }
}

class ComponentSearchParamsMapper
    extends ClassMapperBase<ComponentSearchParams> {
  ComponentSearchParamsMapper._();

  static ComponentSearchParamsMapper? _instance;
  static ComponentSearchParamsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ComponentSearchParamsMapper._());
      PagingSearchParamsMapper.ensureInitialized();
      StockFilterMapper.ensureInitialized();
      ComponentSortMapper.ensureInitialized();
      SearchOptionsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ComponentSearchParams';

  static int? _$projectId(ComponentSearchParams v) => v.projectId;
  static const Field<ComponentSearchParams, int> _f$projectId = Field(
    'projectId',
    _$projectId,
    opt: true,
  );
  static int? _$projectOptionId(ComponentSearchParams v) => v.projectOptionId;
  static const Field<ComponentSearchParams, int> _f$projectOptionId = Field(
    'projectOptionId',
    _$projectOptionId,
    opt: true,
  );
  static String _$name(ComponentSearchParams v) => v.name;
  static const Field<ComponentSearchParams, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: "",
  );
  static List<int> _$categoryIds(ComponentSearchParams v) => v.categoryIds;
  static const Field<ComponentSearchParams, List<int>> _f$categoryIds = Field(
    'categoryIds',
    _$categoryIds,
    opt: true,
    def: const [],
  );
  static List<int> _$typeIds(ComponentSearchParams v) => v.typeIds;
  static const Field<ComponentSearchParams, List<int>> _f$typeIds = Field(
    'typeIds',
    _$typeIds,
    opt: true,
    def: const [],
  );
  static StockFilter _$stockFilter(ComponentSearchParams v) => v.stockFilter;
  static const Field<ComponentSearchParams, StockFilter> _f$stockFilter = Field(
    'stockFilter',
    _$stockFilter,
    opt: true,
    def: StockFilter.all,
  );
  static ComponentSort _$sort(ComponentSearchParams v) => v.sort;
  static const Field<ComponentSearchParams, ComponentSort> _f$sort = Field(
    'sort',
    _$sort,
    opt: true,
    def: ComponentSort.added,
  );
  static int _$page(ComponentSearchParams v) => v.page;
  static const Field<ComponentSearchParams, int> _f$page = Field(
    'page',
    _$page,
    opt: true,
    def: 0,
  );
  static int _$size(ComponentSearchParams v) => v.size;
  static const Field<ComponentSearchParams, int> _f$size = Field(
    'size',
    _$size,
    opt: true,
    def: 12,
  );
  static SearchOptions _$searchOptions(ComponentSearchParams v) =>
      v.searchOptions;
  static const Field<ComponentSearchParams, SearchOptions> _f$searchOptions =
      Field(
        'searchOptions',
        _$searchOptions,
        opt: true,
        def: const SearchOptions(),
      );
  static int? _$focusId(ComponentSearchParams v) => v.focusId;
  static const Field<ComponentSearchParams, int> _f$focusId = Field(
    'focusId',
    _$focusId,
    opt: true,
  );

  @override
  final MappableFields<ComponentSearchParams> fields = const {
    #projectId: _f$projectId,
    #projectOptionId: _f$projectOptionId,
    #name: _f$name,
    #categoryIds: _f$categoryIds,
    #typeIds: _f$typeIds,
    #stockFilter: _f$stockFilter,
    #sort: _f$sort,
    #page: _f$page,
    #size: _f$size,
    #searchOptions: _f$searchOptions,
    #focusId: _f$focusId,
  };

  static ComponentSearchParams _instantiate(DecodingData data) {
    return ComponentSearchParams(
      projectId: data.dec(_f$projectId),
      projectOptionId: data.dec(_f$projectOptionId),
      name: data.dec(_f$name),
      categoryIds: data.dec(_f$categoryIds),
      typeIds: data.dec(_f$typeIds),
      stockFilter: data.dec(_f$stockFilter),
      sort: data.dec(_f$sort),
      page: data.dec(_f$page),
      size: data.dec(_f$size),
      searchOptions: data.dec(_f$searchOptions),
      focusId: data.dec(_f$focusId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ComponentSearchParams fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ComponentSearchParams>(map);
  }

  static ComponentSearchParams fromJson(String json) {
    return ensureInitialized().decodeJson<ComponentSearchParams>(json);
  }
}

mixin ComponentSearchParamsMappable {
  String toJson() {
    return ComponentSearchParamsMapper.ensureInitialized()
        .encodeJson<ComponentSearchParams>(this as ComponentSearchParams);
  }

  Map<String, dynamic> toMap() {
    return ComponentSearchParamsMapper.ensureInitialized()
        .encodeMap<ComponentSearchParams>(this as ComponentSearchParams);
  }

  ComponentSearchParamsCopyWith<
    ComponentSearchParams,
    ComponentSearchParams,
    ComponentSearchParams
  >
  get copyWith =>
      _ComponentSearchParamsCopyWithImpl<
        ComponentSearchParams,
        ComponentSearchParams
      >(this as ComponentSearchParams, $identity, $identity);
  @override
  String toString() {
    return ComponentSearchParamsMapper.ensureInitialized().stringifyValue(
      this as ComponentSearchParams,
    );
  }

  @override
  bool operator ==(Object other) {
    return ComponentSearchParamsMapper.ensureInitialized().equalsValue(
      this as ComponentSearchParams,
      other,
    );
  }

  @override
  int get hashCode {
    return ComponentSearchParamsMapper.ensureInitialized().hashValue(
      this as ComponentSearchParams,
    );
  }
}

extension ComponentSearchParamsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ComponentSearchParams, $Out> {
  ComponentSearchParamsCopyWith<$R, ComponentSearchParams, $Out>
  get $asComponentSearchParams => $base.as(
    (v, t, t2) => _ComponentSearchParamsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ComponentSearchParamsCopyWith<
  $R,
  $In extends ComponentSearchParams,
  $Out
>
    implements PagingSearchParamsCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>> get categoryIds;
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>> get typeIds;
  @override
  SearchOptionsCopyWith<$R, SearchOptions, SearchOptions> get searchOptions;
  @override
  $R call({
    int? projectId,
    int? projectOptionId,
    String? name,
    List<int>? categoryIds,
    List<int>? typeIds,
    StockFilter? stockFilter,
    ComponentSort? sort,
    int? page,
    int? size,
    SearchOptions? searchOptions,
    int? focusId,
  });
  ComponentSearchParamsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ComponentSearchParamsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ComponentSearchParams, $Out>
    implements ComponentSearchParamsCopyWith<$R, ComponentSearchParams, $Out> {
  _ComponentSearchParamsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ComponentSearchParams> $mapper =
      ComponentSearchParamsMapper.ensureInitialized();
  @override
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>> get categoryIds =>
      ListCopyWith(
        $value.categoryIds,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(categoryIds: v),
      );
  @override
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>> get typeIds =>
      ListCopyWith(
        $value.typeIds,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(typeIds: v),
      );
  @override
  SearchOptionsCopyWith<$R, SearchOptions, SearchOptions> get searchOptions =>
      $value.searchOptions.copyWith.$chain((v) => call(searchOptions: v));
  @override
  $R call({
    Object? projectId = $none,
    Object? projectOptionId = $none,
    String? name,
    List<int>? categoryIds,
    List<int>? typeIds,
    StockFilter? stockFilter,
    ComponentSort? sort,
    int? page,
    int? size,
    SearchOptions? searchOptions,
    Object? focusId = $none,
  }) => $apply(
    FieldCopyWithData({
      if (projectId != $none) #projectId: projectId,
      if (projectOptionId != $none) #projectOptionId: projectOptionId,
      if (name != null) #name: name,
      if (categoryIds != null) #categoryIds: categoryIds,
      if (typeIds != null) #typeIds: typeIds,
      if (stockFilter != null) #stockFilter: stockFilter,
      if (sort != null) #sort: sort,
      if (page != null) #page: page,
      if (size != null) #size: size,
      if (searchOptions != null) #searchOptions: searchOptions,
      if (focusId != $none) #focusId: focusId,
    }),
  );
  @override
  ComponentSearchParams $make(CopyWithData data) => ComponentSearchParams(
    projectId: data.get(#projectId, or: $value.projectId),
    projectOptionId: data.get(#projectOptionId, or: $value.projectOptionId),
    name: data.get(#name, or: $value.name),
    categoryIds: data.get(#categoryIds, or: $value.categoryIds),
    typeIds: data.get(#typeIds, or: $value.typeIds),
    stockFilter: data.get(#stockFilter, or: $value.stockFilter),
    sort: data.get(#sort, or: $value.sort),
    page: data.get(#page, or: $value.page),
    size: data.get(#size, or: $value.size),
    searchOptions: data.get(#searchOptions, or: $value.searchOptions),
    focusId: data.get(#focusId, or: $value.focusId),
  );

  @override
  ComponentSearchParamsCopyWith<$R2, ComponentSearchParams, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ComponentSearchParamsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

