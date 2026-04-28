// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'project_item.dart';

class ProjectItemMapper extends ClassMapperBase<ProjectItem> {
  ProjectItemMapper._();

  static ProjectItemMapper? _instance;
  static ProjectItemMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProjectItemMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ProjectItem';

  static int _$id(ProjectItem v) => v.id;
  static const Field<ProjectItem, int> _f$id = Field(
    'id',
    _$id,
    opt: true,
    def: 0,
  );
  static int _$quantity(ProjectItem v) => v.quantity;
  static const Field<ProjectItem, int> _f$quantity = Field(
    'quantity',
    _$quantity,
    opt: true,
    def: 1,
  );
  static ToOne<Component> _$component(ProjectItem v) => v.component;
  static const Field<ProjectItem, ToOne<Component>> _f$component = Field(
    'component',
    _$component,
    mode: FieldMode.member,
  );
  static ToOne<ComponentOption> _$componentOption(ProjectItem v) =>
      v.componentOption;
  static const Field<ProjectItem, ToOne<ComponentOption>> _f$componentOption =
      Field('componentOption', _$componentOption, mode: FieldMode.member);
  static ToOne<ProjectOption> _$projectOption(ProjectItem v) => v.projectOption;
  static const Field<ProjectItem, ToOne<ProjectOption>> _f$projectOption =
      Field('projectOption', _$projectOption, mode: FieldMode.member);
  static ToOne<Project> _$project(ProjectItem v) => v.project;
  static const Field<ProjectItem, ToOne<Project>> _f$project = Field(
    'project',
    _$project,
    mode: FieldMode.member,
  );

  @override
  final MappableFields<ProjectItem> fields = const {
    #id: _f$id,
    #quantity: _f$quantity,
    #component: _f$component,
    #componentOption: _f$componentOption,
    #projectOption: _f$projectOption,
    #project: _f$project,
  };

  static ProjectItem _instantiate(DecodingData data) {
    return ProjectItem(id: data.dec(_f$id), quantity: data.dec(_f$quantity));
  }

  @override
  final Function instantiate = _instantiate;

  static ProjectItem fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProjectItem>(map);
  }

  static ProjectItem fromJson(String json) {
    return ensureInitialized().decodeJson<ProjectItem>(json);
  }
}

mixin ProjectItemMappable {
  String toJson() {
    return ProjectItemMapper.ensureInitialized().encodeJson<ProjectItem>(
      this as ProjectItem,
    );
  }

  Map<String, dynamic> toMap() {
    return ProjectItemMapper.ensureInitialized().encodeMap<ProjectItem>(
      this as ProjectItem,
    );
  }
}

