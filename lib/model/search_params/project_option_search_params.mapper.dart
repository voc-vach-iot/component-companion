// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'project_option_search_params.dart';

class ProjectOptionSearchParamsMapper
    extends ClassMapperBase<ProjectOptionSearchParams> {
  ProjectOptionSearchParamsMapper._();

  static ProjectOptionSearchParamsMapper? _instance;
  static ProjectOptionSearchParamsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = ProjectOptionSearchParamsMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'ProjectOptionSearchParams';

  static int? _$projectId(ProjectOptionSearchParams v) => v.projectId;
  static const Field<ProjectOptionSearchParams, int> _f$projectId = Field(
    'projectId',
    _$projectId,
    opt: true,
  );
  static String _$name(ProjectOptionSearchParams v) => v.name;
  static const Field<ProjectOptionSearchParams, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
    def: "",
  );

  @override
  final MappableFields<ProjectOptionSearchParams> fields = const {
    #projectId: _f$projectId,
    #name: _f$name,
  };

  static ProjectOptionSearchParams _instantiate(DecodingData data) {
    return ProjectOptionSearchParams(
      projectId: data.dec(_f$projectId),
      name: data.dec(_f$name),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProjectOptionSearchParams fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProjectOptionSearchParams>(map);
  }

  static ProjectOptionSearchParams fromJson(String json) {
    return ensureInitialized().decodeJson<ProjectOptionSearchParams>(json);
  }
}

mixin ProjectOptionSearchParamsMappable {
  String toJson() {
    return ProjectOptionSearchParamsMapper.ensureInitialized()
        .encodeJson<ProjectOptionSearchParams>(
          this as ProjectOptionSearchParams,
        );
  }

  Map<String, dynamic> toMap() {
    return ProjectOptionSearchParamsMapper.ensureInitialized()
        .encodeMap<ProjectOptionSearchParams>(
          this as ProjectOptionSearchParams,
        );
  }

  ProjectOptionSearchParamsCopyWith<
    ProjectOptionSearchParams,
    ProjectOptionSearchParams,
    ProjectOptionSearchParams
  >
  get copyWith =>
      _ProjectOptionSearchParamsCopyWithImpl<
        ProjectOptionSearchParams,
        ProjectOptionSearchParams
      >(this as ProjectOptionSearchParams, $identity, $identity);
  @override
  String toString() {
    return ProjectOptionSearchParamsMapper.ensureInitialized().stringifyValue(
      this as ProjectOptionSearchParams,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProjectOptionSearchParamsMapper.ensureInitialized().equalsValue(
      this as ProjectOptionSearchParams,
      other,
    );
  }

  @override
  int get hashCode {
    return ProjectOptionSearchParamsMapper.ensureInitialized().hashValue(
      this as ProjectOptionSearchParams,
    );
  }
}

extension ProjectOptionSearchParamsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProjectOptionSearchParams, $Out> {
  ProjectOptionSearchParamsCopyWith<$R, ProjectOptionSearchParams, $Out>
  get $asProjectOptionSearchParams => $base.as(
    (v, t, t2) => _ProjectOptionSearchParamsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ProjectOptionSearchParamsCopyWith<
  $R,
  $In extends ProjectOptionSearchParams,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? projectId, String? name});
  ProjectOptionSearchParamsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProjectOptionSearchParamsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProjectOptionSearchParams, $Out>
    implements
        ProjectOptionSearchParamsCopyWith<$R, ProjectOptionSearchParams, $Out> {
  _ProjectOptionSearchParamsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProjectOptionSearchParams> $mapper =
      ProjectOptionSearchParamsMapper.ensureInitialized();
  @override
  $R call({Object? projectId = $none, String? name}) => $apply(
    FieldCopyWithData({
      if (projectId != $none) #projectId: projectId,
      if (name != null) #name: name,
    }),
  );
  @override
  ProjectOptionSearchParams $make(CopyWithData data) =>
      ProjectOptionSearchParams(
        projectId: data.get(#projectId, or: $value.projectId),
        name: data.get(#name, or: $value.name),
      );

  @override
  ProjectOptionSearchParamsCopyWith<$R2, ProjectOptionSearchParams, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ProjectOptionSearchParamsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

