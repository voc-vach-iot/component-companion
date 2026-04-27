// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'component_option_search_params.dart';

class ComponentOptionSearchParamsMapper
    extends ClassMapperBase<ComponentOptionSearchParams> {
  ComponentOptionSearchParamsMapper._();

  static ComponentOptionSearchParamsMapper? _instance;
  static ComponentOptionSearchParamsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = ComponentOptionSearchParamsMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'ComponentOptionSearchParams';

  static int? _$componentId(ComponentOptionSearchParams v) => v.componentId;
  static const Field<ComponentOptionSearchParams, int> _f$componentId = Field(
    'componentId',
    _$componentId,
    opt: true,
  );
  static String _$name(ComponentOptionSearchParams v) => v.name;
  static const Field<ComponentOptionSearchParams, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: "",
  );

  @override
  final MappableFields<ComponentOptionSearchParams> fields = const {
    #componentId: _f$componentId,
    #name: _f$name,
  };

  static ComponentOptionSearchParams _instantiate(DecodingData data) {
    return ComponentOptionSearchParams(
      componentId: data.dec(_f$componentId),
      name: data.dec(_f$name),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ComponentOptionSearchParams fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ComponentOptionSearchParams>(map);
  }

  static ComponentOptionSearchParams fromJson(String json) {
    return ensureInitialized().decodeJson<ComponentOptionSearchParams>(json);
  }
}

mixin ComponentOptionSearchParamsMappable {
  String toJson() {
    return ComponentOptionSearchParamsMapper.ensureInitialized()
        .encodeJson<ComponentOptionSearchParams>(
          this as ComponentOptionSearchParams,
        );
  }

  Map<String, dynamic> toMap() {
    return ComponentOptionSearchParamsMapper.ensureInitialized()
        .encodeMap<ComponentOptionSearchParams>(
          this as ComponentOptionSearchParams,
        );
  }

  ComponentOptionSearchParamsCopyWith<
    ComponentOptionSearchParams,
    ComponentOptionSearchParams,
    ComponentOptionSearchParams
  >
  get copyWith =>
      _ComponentOptionSearchParamsCopyWithImpl<
        ComponentOptionSearchParams,
        ComponentOptionSearchParams
      >(this as ComponentOptionSearchParams, $identity, $identity);
  @override
  String toString() {
    return ComponentOptionSearchParamsMapper.ensureInitialized().stringifyValue(
      this as ComponentOptionSearchParams,
    );
  }

  @override
  bool operator ==(Object other) {
    return ComponentOptionSearchParamsMapper.ensureInitialized().equalsValue(
      this as ComponentOptionSearchParams,
      other,
    );
  }

  @override
  int get hashCode {
    return ComponentOptionSearchParamsMapper.ensureInitialized().hashValue(
      this as ComponentOptionSearchParams,
    );
  }
}

extension ComponentOptionSearchParamsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ComponentOptionSearchParams, $Out> {
  ComponentOptionSearchParamsCopyWith<$R, ComponentOptionSearchParams, $Out>
  get $asComponentOptionSearchParams => $base.as(
    (v, t, t2) => _ComponentOptionSearchParamsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ComponentOptionSearchParamsCopyWith<
  $R,
  $In extends ComponentOptionSearchParams,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? componentId, String? name});
  ComponentOptionSearchParamsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ComponentOptionSearchParamsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ComponentOptionSearchParams, $Out>
    implements
        ComponentOptionSearchParamsCopyWith<
          $R,
          ComponentOptionSearchParams,
          $Out
        > {
  _ComponentOptionSearchParamsCopyWithImpl(
    super.value,
    super.then,
    super.then2,
  );

  @override
  late final ClassMapperBase<ComponentOptionSearchParams> $mapper =
      ComponentOptionSearchParamsMapper.ensureInitialized();
  @override
  $R call({Object? componentId = $none, String? name}) => $apply(
    FieldCopyWithData({
      if (componentId != $none) #componentId: componentId,
      if (name != null) #name: name,
    }),
  );
  @override
  ComponentOptionSearchParams $make(CopyWithData data) =>
      ComponentOptionSearchParams(
        componentId: data.get(#componentId, or: $value.componentId),
        name: data.get(#name, or: $value.name),
      );

  @override
  ComponentOptionSearchParamsCopyWith<$R2, ComponentOptionSearchParams, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ComponentOptionSearchParamsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

