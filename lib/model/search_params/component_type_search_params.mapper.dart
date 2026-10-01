// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'component_type_search_params.dart';

class ComponentTypeSearchParamsMapper
    extends ClassMapperBase<ComponentTypeSearchParams> {
  ComponentTypeSearchParamsMapper._();

  static ComponentTypeSearchParamsMapper? _instance;
  static ComponentTypeSearchParamsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = ComponentTypeSearchParamsMapper._(),
      );
      PagingSearchParamsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ComponentTypeSearchParams';

  static String _$name(ComponentTypeSearchParams v) => v.name;
  static const Field<ComponentTypeSearchParams, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: "",
  );
  static int _$page(ComponentTypeSearchParams v) => v.page;
  static const Field<ComponentTypeSearchParams, int> _f$page = Field(
    'page',
    _$page,
    opt: true,
    def: 0,
  );
  static int _$size(ComponentTypeSearchParams v) => v.size;
  static const Field<ComponentTypeSearchParams, int> _f$size = Field(
    'size',
    _$size,
    opt: true,
    def: 12,
  );

  @override
  final MappableFields<ComponentTypeSearchParams> fields = const {
    #name: _f$name,
    #page: _f$page,
    #size: _f$size,
  };

  static ComponentTypeSearchParams _instantiate(DecodingData data) {
    return ComponentTypeSearchParams(
      name: data.dec(_f$name),
      page: data.dec(_f$page),
      size: data.dec(_f$size),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ComponentTypeSearchParams fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ComponentTypeSearchParams>(map);
  }

  static ComponentTypeSearchParams fromJson(String json) {
    return ensureInitialized().decodeJson<ComponentTypeSearchParams>(json);
  }
}

mixin ComponentTypeSearchParamsMappable {
  String toJson() {
    return ComponentTypeSearchParamsMapper.ensureInitialized()
        .encodeJson<ComponentTypeSearchParams>(
          this as ComponentTypeSearchParams,
        );
  }

  Map<String, dynamic> toMap() {
    return ComponentTypeSearchParamsMapper.ensureInitialized()
        .encodeMap<ComponentTypeSearchParams>(
          this as ComponentTypeSearchParams,
        );
  }

  ComponentTypeSearchParamsCopyWith<
    ComponentTypeSearchParams,
    ComponentTypeSearchParams,
    ComponentTypeSearchParams
  >
  get copyWith =>
      _ComponentTypeSearchParamsCopyWithImpl<
        ComponentTypeSearchParams,
        ComponentTypeSearchParams
      >(this as ComponentTypeSearchParams, $identity, $identity);
  @override
  String toString() {
    return ComponentTypeSearchParamsMapper.ensureInitialized().stringifyValue(
      this as ComponentTypeSearchParams,
    );
  }

  @override
  bool operator ==(Object other) {
    return ComponentTypeSearchParamsMapper.ensureInitialized().equalsValue(
      this as ComponentTypeSearchParams,
      other,
    );
  }

  @override
  int get hashCode {
    return ComponentTypeSearchParamsMapper.ensureInitialized().hashValue(
      this as ComponentTypeSearchParams,
    );
  }
}

extension ComponentTypeSearchParamsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ComponentTypeSearchParams, $Out> {
  ComponentTypeSearchParamsCopyWith<$R, ComponentTypeSearchParams, $Out>
  get $asComponentTypeSearchParams => $base.as(
    (v, t, t2) => _ComponentTypeSearchParamsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ComponentTypeSearchParamsCopyWith<
  $R,
  $In extends ComponentTypeSearchParams,
  $Out
>
    implements PagingSearchParamsCopyWith<$R, $In, $Out> {
  @override
  $R call({String? name, int? page, int? size});
  ComponentTypeSearchParamsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ComponentTypeSearchParamsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ComponentTypeSearchParams, $Out>
    implements
        ComponentTypeSearchParamsCopyWith<$R, ComponentTypeSearchParams, $Out> {
  _ComponentTypeSearchParamsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ComponentTypeSearchParams> $mapper =
      ComponentTypeSearchParamsMapper.ensureInitialized();
  @override
  $R call({String? name, int? page, int? size}) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (page != null) #page: page,
      if (size != null) #size: size,
    }),
  );
  @override
  ComponentTypeSearchParams $make(CopyWithData data) =>
      ComponentTypeSearchParams(
        name: data.get(#name, or: $value.name),
        page: data.get(#page, or: $value.page),
        size: data.get(#size, or: $value.size),
      );

  @override
  ComponentTypeSearchParamsCopyWith<$R2, ComponentTypeSearchParams, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ComponentTypeSearchParamsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

