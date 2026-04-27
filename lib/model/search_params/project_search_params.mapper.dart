// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'project_search_params.dart';

class ProjectSearchParamsMapper extends ClassMapperBase<ProjectSearchParams> {
  ProjectSearchParamsMapper._();

  static ProjectSearchParamsMapper? _instance;
  static ProjectSearchParamsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProjectSearchParamsMapper._());
      PagingSearchParamsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ProjectSearchParams';

  static String _$name(ProjectSearchParams v) => v.name;
  static const Field<ProjectSearchParams, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: "",
  );
  static int _$page(ProjectSearchParams v) => v.page;
  static const Field<ProjectSearchParams, int> _f$page = Field(
    'page',
    _$page,
    opt: true,
    def: 0,
  );
  static int _$size(ProjectSearchParams v) => v.size;
  static const Field<ProjectSearchParams, int> _f$size = Field(
    'size',
    _$size,
    opt: true,
    def: 12,
  );

  @override
  final MappableFields<ProjectSearchParams> fields = const {
    #name: _f$name,
    #page: _f$page,
    #size: _f$size,
  };

  static ProjectSearchParams _instantiate(DecodingData data) {
    return ProjectSearchParams(
      name: data.dec(_f$name),
      page: data.dec(_f$page),
      size: data.dec(_f$size),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProjectSearchParams fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProjectSearchParams>(map);
  }

  static ProjectSearchParams fromJson(String json) {
    return ensureInitialized().decodeJson<ProjectSearchParams>(json);
  }
}

mixin ProjectSearchParamsMappable {
  String toJson() {
    return ProjectSearchParamsMapper.ensureInitialized()
        .encodeJson<ProjectSearchParams>(this as ProjectSearchParams);
  }

  Map<String, dynamic> toMap() {
    return ProjectSearchParamsMapper.ensureInitialized()
        .encodeMap<ProjectSearchParams>(this as ProjectSearchParams);
  }

  ProjectSearchParamsCopyWith<
    ProjectSearchParams,
    ProjectSearchParams,
    ProjectSearchParams
  >
  get copyWith =>
      _ProjectSearchParamsCopyWithImpl<
        ProjectSearchParams,
        ProjectSearchParams
      >(this as ProjectSearchParams, $identity, $identity);
  @override
  String toString() {
    return ProjectSearchParamsMapper.ensureInitialized().stringifyValue(
      this as ProjectSearchParams,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProjectSearchParamsMapper.ensureInitialized().equalsValue(
      this as ProjectSearchParams,
      other,
    );
  }

  @override
  int get hashCode {
    return ProjectSearchParamsMapper.ensureInitialized().hashValue(
      this as ProjectSearchParams,
    );
  }
}

extension ProjectSearchParamsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProjectSearchParams, $Out> {
  ProjectSearchParamsCopyWith<$R, ProjectSearchParams, $Out>
  get $asProjectSearchParams => $base.as(
    (v, t, t2) => _ProjectSearchParamsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ProjectSearchParamsCopyWith<
  $R,
  $In extends ProjectSearchParams,
  $Out
>
    implements PagingSearchParamsCopyWith<$R, $In, $Out> {
  @override
  $R call({String? name, int? page, int? size});
  ProjectSearchParamsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProjectSearchParamsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProjectSearchParams, $Out>
    implements ProjectSearchParamsCopyWith<$R, ProjectSearchParams, $Out> {
  _ProjectSearchParamsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProjectSearchParams> $mapper =
      ProjectSearchParamsMapper.ensureInitialized();
  @override
  $R call({String? name, int? page, int? size}) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (page != null) #page: page,
      if (size != null) #size: size,
    }),
  );
  @override
  ProjectSearchParams $make(CopyWithData data) => ProjectSearchParams(
    name: data.get(#name, or: $value.name),
    page: data.get(#page, or: $value.page),
    size: data.get(#size, or: $value.size),
  );

  @override
  ProjectSearchParamsCopyWith<$R2, ProjectSearchParams, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ProjectSearchParamsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

