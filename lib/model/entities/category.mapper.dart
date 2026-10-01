// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'category.dart';

class CategoryMapper extends ClassMapperBase<Category> {
  CategoryMapper._();

  static CategoryMapper? _instance;
  static CategoryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CategoryMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Category';

  static int _$id(Category v) => v.id;
  static const Field<Category, int> _f$id = Field(
    'id',
    _$id,
    opt: true,
    def: 0,
  );
  static String _$name(Category v) => v.name;
  static const Field<Category, String> _f$name = Field('name', _$name);
  static String _$description(Category v) => v.description;
  static const Field<Category, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
    def: "",
  );
  static int _$colorValue(Category v) => v.colorValue;
  static const Field<Category, int> _f$colorValue = Field(
    'colorValue',
    _$colorValue,
  );
  static String _$iconSvg(Category v) => v.iconSvg;
  static const Field<Category, String> _f$iconSvg = Field(
    'iconSvg',
    _$iconSvg,
    opt: true,
    def: "",
  );
  static List<String> _$keywords(Category v) => v.keywords;
  static const Field<Category, List<String>> _f$keywords = Field(
    'keywords',
    _$keywords,
    opt: true,
  );
  static ToMany<Component> _$component(Category v) => v.component;
  static const Field<Category, ToMany<Component>> _f$component = Field(
    'component',
    _$component,
    mode: FieldMode.member,
  );
  static ToMany<ComponentType> _$types(Category v) => v.types;
  static const Field<Category, ToMany<ComponentType>> _f$types = Field(
    'types',
    _$types,
    mode: FieldMode.member,
  );

  @override
  final MappableFields<Category> fields = const {
    #id: _f$id,
    #name: _f$name,
    #description: _f$description,
    #colorValue: _f$colorValue,
    #iconSvg: _f$iconSvg,
    #keywords: _f$keywords,
    #component: _f$component,
    #types: _f$types,
  };

  static Category _instantiate(DecodingData data) {
    return Category(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      colorValue: data.dec(_f$colorValue),
      iconSvg: data.dec(_f$iconSvg),
      keywords: data.dec(_f$keywords),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Category fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Category>(map);
  }

  static Category fromJson(String json) {
    return ensureInitialized().decodeJson<Category>(json);
  }
}

mixin CategoryMappable {
  String toJson() {
    return CategoryMapper.ensureInitialized().encodeJson<Category>(
      this as Category,
    );
  }

  Map<String, dynamic> toMap() {
    return CategoryMapper.ensureInitialized().encodeMap<Category>(
      this as Category,
    );
  }
}

