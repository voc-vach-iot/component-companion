// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'paging_search_params.dart';

class PagingSearchParamsMapper extends ClassMapperBase<PagingSearchParams> {
  PagingSearchParamsMapper._();

  static PagingSearchParamsMapper? _instance;
  static PagingSearchParamsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PagingSearchParamsMapper._());
      SearchOptionsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PagingSearchParams';

  static int _$page(PagingSearchParams v) => v.page;
  static const Field<PagingSearchParams, int> _f$page = Field('page', _$page);
  static int _$size(PagingSearchParams v) => v.size;
  static const Field<PagingSearchParams, int> _f$size = Field('size', _$size);
  static SearchOptions _$searchOptions(PagingSearchParams v) => v.searchOptions;
  static const Field<PagingSearchParams, SearchOptions> _f$searchOptions =
      Field(
        'searchOptions',
        _$searchOptions,
        opt: true,
        def: const SearchOptions(),
      );
  static int? _$focusId(PagingSearchParams v) => v.focusId;
  static const Field<PagingSearchParams, int> _f$focusId = Field(
    'focusId',
    _$focusId,
    opt: true,
  );

  @override
  final MappableFields<PagingSearchParams> fields = const {
    #page: _f$page,
    #size: _f$size,
    #searchOptions: _f$searchOptions,
    #focusId: _f$focusId,
  };

  static PagingSearchParams _instantiate(DecodingData data) {
    return PagingSearchParams(
      page: data.dec(_f$page),
      size: data.dec(_f$size),
      searchOptions: data.dec(_f$searchOptions),
      focusId: data.dec(_f$focusId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PagingSearchParams fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PagingSearchParams>(map);
  }

  static PagingSearchParams fromJson(String json) {
    return ensureInitialized().decodeJson<PagingSearchParams>(json);
  }
}

mixin PagingSearchParamsMappable {
  String toJson() {
    return PagingSearchParamsMapper.ensureInitialized()
        .encodeJson<PagingSearchParams>(this as PagingSearchParams);
  }

  Map<String, dynamic> toMap() {
    return PagingSearchParamsMapper.ensureInitialized()
        .encodeMap<PagingSearchParams>(this as PagingSearchParams);
  }

  PagingSearchParamsCopyWith<
    PagingSearchParams,
    PagingSearchParams,
    PagingSearchParams
  >
  get copyWith =>
      _PagingSearchParamsCopyWithImpl<PagingSearchParams, PagingSearchParams>(
        this as PagingSearchParams,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PagingSearchParamsMapper.ensureInitialized().stringifyValue(
      this as PagingSearchParams,
    );
  }

  @override
  bool operator ==(Object other) {
    return PagingSearchParamsMapper.ensureInitialized().equalsValue(
      this as PagingSearchParams,
      other,
    );
  }

  @override
  int get hashCode {
    return PagingSearchParamsMapper.ensureInitialized().hashValue(
      this as PagingSearchParams,
    );
  }
}

extension PagingSearchParamsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PagingSearchParams, $Out> {
  PagingSearchParamsCopyWith<$R, PagingSearchParams, $Out>
  get $asPagingSearchParams => $base.as(
    (v, t, t2) => _PagingSearchParamsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PagingSearchParamsCopyWith<
  $R,
  $In extends PagingSearchParams,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  SearchOptionsCopyWith<$R, SearchOptions, SearchOptions> get searchOptions;
  $R call({int? page, int? size, SearchOptions? searchOptions, int? focusId});
  PagingSearchParamsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PagingSearchParamsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PagingSearchParams, $Out>
    implements PagingSearchParamsCopyWith<$R, PagingSearchParams, $Out> {
  _PagingSearchParamsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PagingSearchParams> $mapper =
      PagingSearchParamsMapper.ensureInitialized();
  @override
  SearchOptionsCopyWith<$R, SearchOptions, SearchOptions> get searchOptions =>
      $value.searchOptions.copyWith.$chain((v) => call(searchOptions: v));
  @override
  $R call({
    int? page,
    int? size,
    SearchOptions? searchOptions,
    Object? focusId = $none,
  }) => $apply(
    FieldCopyWithData({
      if (page != null) #page: page,
      if (size != null) #size: size,
      if (searchOptions != null) #searchOptions: searchOptions,
      if (focusId != $none) #focusId: focusId,
    }),
  );
  @override
  PagingSearchParams $make(CopyWithData data) => PagingSearchParams(
    page: data.get(#page, or: $value.page),
    size: data.get(#size, or: $value.size),
    searchOptions: data.get(#searchOptions, or: $value.searchOptions),
    focusId: data.get(#focusId, or: $value.focusId),
  );

  @override
  PagingSearchParamsCopyWith<$R2, PagingSearchParams, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PagingSearchParamsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

