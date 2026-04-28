// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'project.dart';

class ProjectMapper extends ClassMapperBase<Project> {
  ProjectMapper._();

  static ProjectMapper? _instance;
  static ProjectMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProjectMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Project';

  static int _$id(Project v) => v.id;
  static const Field<Project, int> _f$id = Field('id', _$id, opt: true, def: 0);
  static String _$name(Project v) => v.name;
  static const Field<Project, String> _f$name = Field('name', _$name);
  static ToMany<ProjectItem> _$baseItems(Project v) => v.baseItems;
  static const Field<Project, ToMany<ProjectItem>> _f$baseItems = Field(
    'baseItems',
    _$baseItems,
    mode: FieldMode.member,
  );
  static ToMany<ProjectOption> _$projectOptions(Project v) => v.projectOptions;
  static const Field<Project, ToMany<ProjectOption>> _f$projectOptions = Field(
    'projectOptions',
    _$projectOptions,
    mode: FieldMode.member,
  );

  @override
  final MappableFields<Project> fields = const {
    #id: _f$id,
    #name: _f$name,
    #baseItems: _f$baseItems,
    #projectOptions: _f$projectOptions,
  };

  static Project _instantiate(DecodingData data) {
    return Project(id: data.dec(_f$id), name: data.dec(_f$name));
  }

  @override
  final Function instantiate = _instantiate;

  static Project fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Project>(map);
  }

  static Project fromJson(String json) {
    return ensureInitialized().decodeJson<Project>(json);
  }
}

mixin ProjectMappable {
  String toJson() {
    return ProjectMapper.ensureInitialized().encodeJson<Project>(
      this as Project,
    );
  }

  Map<String, dynamic> toMap() {
    return ProjectMapper.ensureInitialized().encodeMap<Project>(
      this as Project,
    );
  }
}

