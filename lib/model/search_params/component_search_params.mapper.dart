// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'component_search_params.dart';

class ComponentSearchParamsMapper
    extends ClassMapperBase<ComponentSearchParams> {
  ComponentSearchParamsMapper._();

  static ComponentSearchParamsMapper? _instance;
  static ComponentSearchParamsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ComponentSearchParamsMapper._());
      PagingSearchParamsMapper.ensureInitialized();
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

  @override
  final MappableFields<ComponentSearchParams> fields = const {
    #projectId: _f$projectId,
    #projectOptionId: _f$projectOptionId,
    #name: _f$name,
    #page: _f$page,
    #size: _f$size,
  };

  static ComponentSearchParams _instantiate(DecodingData data) {
    return ComponentSearchParams(
      projectId: data.dec(_f$projectId),
      projectOptionId: data.dec(_f$projectOptionId),
      name: data.dec(_f$name),
      page: data.dec(_f$page),
      size: data.dec(_f$size),
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
  @override
  $R call({
    int? projectId,
    int? projectOptionId,
    String? name,
    int? page,
    int? size,
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
  $R call({
    Object? projectId = $none,
    Object? projectOptionId = $none,
    String? name,
    int? page,
    int? size,
  }) => $apply(
    FieldCopyWithData({
      if (projectId != $none) #projectId: projectId,
      if (projectOptionId != $none) #projectOptionId: projectOptionId,
      if (name != null) #name: name,
      if (page != null) #page: page,
      if (size != null) #size: size,
    }),
  );
  @override
  ComponentSearchParams $make(CopyWithData data) => ComponentSearchParams(
    projectId: data.get(#projectId, or: $value.projectId),
    projectOptionId: data.get(#projectOptionId, or: $value.projectOptionId),
    name: data.get(#name, or: $value.name),
    page: data.get(#page, or: $value.page),
    size: data.get(#size, or: $value.size),
  );

  @override
  ComponentSearchParamsCopyWith<$R2, ComponentSearchParams, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ComponentSearchParamsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

