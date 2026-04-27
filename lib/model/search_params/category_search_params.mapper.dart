// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'category_search_params.dart';

class CategorySearchParamsMapper extends ClassMapperBase<CategorySearchParams> {
  CategorySearchParamsMapper._();

  static CategorySearchParamsMapper? _instance;
  static CategorySearchParamsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CategorySearchParamsMapper._());
      PagingSearchParamsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CategorySearchParams';

  static String _$name(CategorySearchParams v) => v.name;
  static const Field<CategorySearchParams, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: "",
  );
  static int _$page(CategorySearchParams v) => v.page;
  static const Field<CategorySearchParams, int> _f$page = Field(
    'page',
    _$page,
    opt: true,
    def: 0,
  );
  static int _$size(CategorySearchParams v) => v.size;
  static const Field<CategorySearchParams, int> _f$size = Field(
    'size',
    _$size,
    opt: true,
    def: 12,
  );

  @override
  final MappableFields<CategorySearchParams> fields = const {
    #name: _f$name,
    #page: _f$page,
    #size: _f$size,
  };

  static CategorySearchParams _instantiate(DecodingData data) {
    return CategorySearchParams(
      name: data.dec(_f$name),
      page: data.dec(_f$page),
      size: data.dec(_f$size),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CategorySearchParams fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CategorySearchParams>(map);
  }

  static CategorySearchParams fromJson(String json) {
    return ensureInitialized().decodeJson<CategorySearchParams>(json);
  }
}

mixin CategorySearchParamsMappable {
  String toJson() {
    return CategorySearchParamsMapper.ensureInitialized()
        .encodeJson<CategorySearchParams>(this as CategorySearchParams);
  }

  Map<String, dynamic> toMap() {
    return CategorySearchParamsMapper.ensureInitialized()
        .encodeMap<CategorySearchParams>(this as CategorySearchParams);
  }

  CategorySearchParamsCopyWith<
    CategorySearchParams,
    CategorySearchParams,
    CategorySearchParams
  >
  get copyWith =>
      _CategorySearchParamsCopyWithImpl<
        CategorySearchParams,
        CategorySearchParams
      >(this as CategorySearchParams, $identity, $identity);
  @override
  String toString() {
    return CategorySearchParamsMapper.ensureInitialized().stringifyValue(
      this as CategorySearchParams,
    );
  }

  @override
  bool operator ==(Object other) {
    return CategorySearchParamsMapper.ensureInitialized().equalsValue(
      this as CategorySearchParams,
      other,
    );
  }

  @override
  int get hashCode {
    return CategorySearchParamsMapper.ensureInitialized().hashValue(
      this as CategorySearchParams,
    );
  }
}

extension CategorySearchParamsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CategorySearchParams, $Out> {
  CategorySearchParamsCopyWith<$R, CategorySearchParams, $Out>
  get $asCategorySearchParams => $base.as(
    (v, t, t2) => _CategorySearchParamsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CategorySearchParamsCopyWith<
  $R,
  $In extends CategorySearchParams,
  $Out
>
    implements PagingSearchParamsCopyWith<$R, $In, $Out> {
  @override
  $R call({String? name, int? page, int? size});
  CategorySearchParamsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CategorySearchParamsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CategorySearchParams, $Out>
    implements CategorySearchParamsCopyWith<$R, CategorySearchParams, $Out> {
  _CategorySearchParamsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CategorySearchParams> $mapper =
      CategorySearchParamsMapper.ensureInitialized();
  @override
  $R call({String? name, int? page, int? size}) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (page != null) #page: page,
      if (size != null) #size: size,
    }),
  );
  @override
  CategorySearchParams $make(CopyWithData data) => CategorySearchParams(
    name: data.get(#name, or: $value.name),
    page: data.get(#page, or: $value.page),
    size: data.get(#size, or: $value.size),
  );

  @override
  CategorySearchParamsCopyWith<$R2, CategorySearchParams, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _CategorySearchParamsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

