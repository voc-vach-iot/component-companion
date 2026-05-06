// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'project_item_search_params.dart';

class ProjectItemSearchParamsMapper
    extends ClassMapperBase<ProjectItemSearchParams> {
  ProjectItemSearchParamsMapper._();

  static ProjectItemSearchParamsMapper? _instance;
  static ProjectItemSearchParamsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = ProjectItemSearchParamsMapper._(),
      );
    }
    return _instance!;
  }

  @override
  final String id = 'ProjectItemSearchParams';

  static int? _$projectId(ProjectItemSearchParams v) => v.projectId;
  static const Field<ProjectItemSearchParams, int> _f$projectId = Field(
    'projectId',
    _$projectId,
    opt: true,
  );
  static int? _$projectOptionId(ProjectItemSearchParams v) => v.projectOptionId;
  static const Field<ProjectItemSearchParams, int> _f$projectOptionId = Field(
    'projectOptionId',
    _$projectOptionId,
    opt: true,
  );

  @override
  final MappableFields<ProjectItemSearchParams> fields = const {
    #projectId: _f$projectId,
    #projectOptionId: _f$projectOptionId,
  };

  static ProjectItemSearchParams _instantiate(DecodingData data) {
    return ProjectItemSearchParams(
      projectId: data.dec(_f$projectId),
      projectOptionId: data.dec(_f$projectOptionId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProjectItemSearchParams fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProjectItemSearchParams>(map);
  }

  static ProjectItemSearchParams fromJson(String json) {
    return ensureInitialized().decodeJson<ProjectItemSearchParams>(json);
  }
}

mixin ProjectItemSearchParamsMappable {
  String toJson() {
    return ProjectItemSearchParamsMapper.ensureInitialized()
        .encodeJson<ProjectItemSearchParams>(this as ProjectItemSearchParams);
  }

  Map<String, dynamic> toMap() {
    return ProjectItemSearchParamsMapper.ensureInitialized()
        .encodeMap<ProjectItemSearchParams>(this as ProjectItemSearchParams);
  }

  ProjectItemSearchParamsCopyWith<
    ProjectItemSearchParams,
    ProjectItemSearchParams,
    ProjectItemSearchParams
  >
  get copyWith =>
      _ProjectItemSearchParamsCopyWithImpl<
        ProjectItemSearchParams,
        ProjectItemSearchParams
      >(this as ProjectItemSearchParams, $identity, $identity);
  @override
  String toString() {
    return ProjectItemSearchParamsMapper.ensureInitialized().stringifyValue(
      this as ProjectItemSearchParams,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProjectItemSearchParamsMapper.ensureInitialized().equalsValue(
      this as ProjectItemSearchParams,
      other,
    );
  }

  @override
  int get hashCode {
    return ProjectItemSearchParamsMapper.ensureInitialized().hashValue(
      this as ProjectItemSearchParams,
    );
  }
}

extension ProjectItemSearchParamsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProjectItemSearchParams, $Out> {
  ProjectItemSearchParamsCopyWith<$R, ProjectItemSearchParams, $Out>
  get $asProjectItemSearchParams => $base.as(
    (v, t, t2) => _ProjectItemSearchParamsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ProjectItemSearchParamsCopyWith<
  $R,
  $In extends ProjectItemSearchParams,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? projectId, int? projectOptionId});
  ProjectItemSearchParamsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProjectItemSearchParamsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProjectItemSearchParams, $Out>
    implements
        ProjectItemSearchParamsCopyWith<$R, ProjectItemSearchParams, $Out> {
  _ProjectItemSearchParamsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProjectItemSearchParams> $mapper =
      ProjectItemSearchParamsMapper.ensureInitialized();
  @override
  $R call({Object? projectId = $none, Object? projectOptionId = $none}) =>
      $apply(
        FieldCopyWithData({
          if (projectId != $none) #projectId: projectId,
          if (projectOptionId != $none) #projectOptionId: projectOptionId,
        }),
      );
  @override
  ProjectItemSearchParams $make(CopyWithData data) => ProjectItemSearchParams(
    projectId: data.get(#projectId, or: $value.projectId),
    projectOptionId: data.get(#projectOptionId, or: $value.projectOptionId),
  );

  @override
  ProjectItemSearchParamsCopyWith<$R2, ProjectItemSearchParams, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ProjectItemSearchParamsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

