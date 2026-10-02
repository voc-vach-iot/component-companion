// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'component_type.dart';

class ComponentTypeMapper extends ClassMapperBase<ComponentType> {
  ComponentTypeMapper._();

  static ComponentTypeMapper? _instance;
  static ComponentTypeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ComponentTypeMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ComponentType';

  static int _$id(ComponentType v) => v.id;
  static const Field<ComponentType, int> _f$id = Field(
    'id',
    _$id,
    opt: true,
    def: 0,
  );
  static String _$name(ComponentType v) => v.name;
  static const Field<ComponentType, String> _f$name = Field('name', _$name);
  static String _$defaultIconSvg(ComponentType v) => v.defaultIconSvg;
  static const Field<ComponentType, String> _f$defaultIconSvg = Field(
    'defaultIconSvg',
    _$defaultIconSvg,
    opt: true,
    def: "",
  );
  static List<String> _$keywords(ComponentType v) => v.keywords;
  static const Field<ComponentType, List<String>> _f$keywords = Field(
    'keywords',
    _$keywords,
    opt: true,
  );
  static List<String> _$attributeTemplate(ComponentType v) =>
      v.attributeTemplate;
  static const Field<ComponentType, List<String>> _f$attributeTemplate = Field(
    'attributeTemplate',
    _$attributeTemplate,
    opt: true,
  );
  static ToOne<Category> _$category(ComponentType v) => v.category;
  static const Field<ComponentType, ToOne<Category>> _f$category = Field(
    'category',
    _$category,
    mode: FieldMode.member,
  );
  static ToMany<Component> _$components(ComponentType v) => v.components;
  static const Field<ComponentType, ToMany<Component>> _f$components = Field(
    'components',
    _$components,
    mode: FieldMode.member,
  );

  @override
  final MappableFields<ComponentType> fields = const {
    #id: _f$id,
    #name: _f$name,
    #defaultIconSvg: _f$defaultIconSvg,
    #keywords: _f$keywords,
    #attributeTemplate: _f$attributeTemplate,
    #category: _f$category,
    #components: _f$components,
  };

  static ComponentType _instantiate(DecodingData data) {
    return ComponentType(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      defaultIconSvg: data.dec(_f$defaultIconSvg),
      keywords: data.dec(_f$keywords),
      attributeTemplate: data.dec(_f$attributeTemplate),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ComponentType fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ComponentType>(map);
  }

  static ComponentType fromJson(String json) {
    return ensureInitialized().decodeJson<ComponentType>(json);
  }
}

mixin ComponentTypeMappable {
  String toJson() {
    return ComponentTypeMapper.ensureInitialized().encodeJson<ComponentType>(
      this as ComponentType,
    );
  }

  Map<String, dynamic> toMap() {
    return ComponentTypeMapper.ensureInitialized().encodeMap<ComponentType>(
      this as ComponentType,
    );
  }
}

