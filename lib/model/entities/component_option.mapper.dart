// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'component_option.dart';

class ComponentOptionMapper extends ClassMapperBase<ComponentOption> {
  ComponentOptionMapper._();

  static ComponentOptionMapper? _instance;
  static ComponentOptionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ComponentOptionMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ComponentOption';

  static int _$id(ComponentOption v) => v.id;
  static const Field<ComponentOption, int> _f$id = Field(
    'id',
    _$id,
    opt: true,
    def: 0,
  );
  static String _$name(ComponentOption v) => v.name;
  static const Field<ComponentOption, String> _f$name = Field('name', _$name);
  static int _$unitsPerPack(ComponentOption v) => v.unitsPerPack;
  static const Field<ComponentOption, int> _f$unitsPerPack = Field(
    'unitsPerPack',
    _$unitsPerPack,
    opt: true,
    def: 1,
  );
  static int _$pricePerPack(ComponentOption v) => v.pricePerPack;
  static const Field<ComponentOption, int> _f$pricePerPack = Field(
    'pricePerPack',
    _$pricePerPack,
  );
  static String _$link(ComponentOption v) => v.link;
  static const Field<ComponentOption, String> _f$link = Field(
    'link',
    _$link,
    opt: true,
    def: "",
  );
  static ToOne<Component> _$component(ComponentOption v) => v.component;
  static const Field<ComponentOption, ToOne<Component>> _f$component = Field(
    'component',
    _$component,
    mode: FieldMode.member,
  );
  static ToMany<ProjectItem> _$projectItem(ComponentOption v) => v.projectItem;
  static const Field<ComponentOption, ToMany<ProjectItem>> _f$projectItem =
      Field('projectItem', _$projectItem, mode: FieldMode.member);

  @override
  final MappableFields<ComponentOption> fields = const {
    #id: _f$id,
    #name: _f$name,
    #unitsPerPack: _f$unitsPerPack,
    #pricePerPack: _f$pricePerPack,
    #link: _f$link,
    #component: _f$component,
    #projectItem: _f$projectItem,
  };

  static ComponentOption _instantiate(DecodingData data) {
    return ComponentOption(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      unitsPerPack: data.dec(_f$unitsPerPack),
      pricePerPack: data.dec(_f$pricePerPack),
      link: data.dec(_f$link),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ComponentOption fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ComponentOption>(map);
  }

  static ComponentOption fromJson(String json) {
    return ensureInitialized().decodeJson<ComponentOption>(json);
  }
}

mixin ComponentOptionMappable {
  String toJson() {
    return ComponentOptionMapper.ensureInitialized()
        .encodeJson<ComponentOption>(this as ComponentOption);
  }

  Map<String, dynamic> toMap() {
    return ComponentOptionMapper.ensureInitialized().encodeMap<ComponentOption>(
      this as ComponentOption,
    );
  }
}

