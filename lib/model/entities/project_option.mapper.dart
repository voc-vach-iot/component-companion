// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'project_option.dart';

class ProjectOptionMapper extends ClassMapperBase<ProjectOption> {
  ProjectOptionMapper._();

  static ProjectOptionMapper? _instance;
  static ProjectOptionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProjectOptionMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ProjectOption';

  static int _$id(ProjectOption v) => v.id;
  static const Field<ProjectOption, int> _f$id = Field(
    'id',
    _$id,
    opt: true,
    def: 0,
  );
  static String _$name(ProjectOption v) => v.name;
  static const Field<ProjectOption, String> _f$name = Field('name', _$name);
  static String _$description(ProjectOption v) => v.description;
  static const Field<ProjectOption, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
    def: "",
  );
  static ToOne<Project> _$project(ProjectOption v) => v.project;
  static const Field<ProjectOption, ToOne<Project>> _f$project = Field(
    'project',
    _$project,
    mode: FieldMode.member,
  );
  static ToMany<ProjectItem> _$items(ProjectOption v) => v.items;
  static const Field<ProjectOption, ToMany<ProjectItem>> _f$items = Field(
    'items',
    _$items,
    mode: FieldMode.member,
  );

  @override
  final MappableFields<ProjectOption> fields = const {
    #id: _f$id,
    #name: _f$name,
    #description: _f$description,
    #project: _f$project,
    #items: _f$items,
  };

  static ProjectOption _instantiate(DecodingData data) {
    return ProjectOption(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      description: data.dec(_f$description),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProjectOption fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProjectOption>(map);
  }

  static ProjectOption fromJson(String json) {
    return ensureInitialized().decodeJson<ProjectOption>(json);
  }
}

mixin ProjectOptionMappable {
  String toJson() {
    return ProjectOptionMapper.ensureInitialized().encodeJson<ProjectOption>(
      this as ProjectOption,
    );
  }

  Map<String, dynamic> toMap() {
    return ProjectOptionMapper.ensureInitialized().encodeMap<ProjectOption>(
      this as ProjectOption,
    );
  }
}

