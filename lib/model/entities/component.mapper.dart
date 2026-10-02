// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'component.dart';

class ComponentMapper extends ClassMapperBase<Component> {
  ComponentMapper._();

  static ComponentMapper? _instance;
  static ComponentMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ComponentMapper._());
      ComponentOptionMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Component';

  static int _$id(Component v) => v.id;
  static const Field<Component, int> _f$id = Field(
    'id',
    _$id,
    opt: true,
    def: 0,
  );
  static String _$name(Component v) => v.name;
  static const Field<Component, String> _f$name = Field('name', _$name);
  static String _$description(Component v) => v.description;
  static const Field<Component, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
    def: "",
  );
  static String _$base64Image(Component v) => v.base64Image;
  static const Field<Component, String> _f$base64Image = Field(
    'base64Image',
    _$base64Image,
    key: r'base64image',
    opt: true,
    def: "",
  );
  static String _$iconSvg(Component v) => v.iconSvg;
  static const Field<Component, String> _f$iconSvg = Field(
    'iconSvg',
    _$iconSvg,
    opt: true,
    def: "",
  );
  static String _$attributesJson(Component v) => v.attributesJson;
  static const Field<Component, String> _f$attributesJson = Field(
    'attributesJson',
    _$attributesJson,
    opt: true,
    def: "",
  );
  static int _$lowStockThreshold(Component v) => v.lowStockThreshold;
  static const Field<Component, int> _f$lowStockThreshold = Field(
    'lowStockThreshold',
    _$lowStockThreshold,
    opt: true,
    def: 0,
  );
  static ToMany<ComponentOption> _$options(Component v) => v.options;
  static dynamic _arg$options(f) => f<ToMany<ComponentOption>>();
  static const Field<Component, List<ComponentOption>> _f$options = Field(
    'options',
    _$options,
    opt: true,
    arg: _arg$options,
  );
  static List<ComponentOption> _$optionsList(Component v) => v.optionsList;
  static const Field<Component, List<ComponentOption>> _f$optionsList = Field(
    'optionsList',
    _$optionsList,
  );
  static ToMany<ProjectItem> _$projectItem(Component v) => v.projectItem;
  static const Field<Component, ToMany<ProjectItem>> _f$projectItem = Field(
    'projectItem',
    _$projectItem,
    mode: FieldMode.member,
  );
  static ToOne<Category> _$category(Component v) => v.category;
  static const Field<Component, ToOne<Category>> _f$category = Field(
    'category',
    _$category,
    mode: FieldMode.member,
  );
  static ToOne<ComponentType> _$type(Component v) => v.type;
  static const Field<Component, ToOne<ComponentType>> _f$type = Field(
    'type',
    _$type,
    mode: FieldMode.member,
  );
  static ToMany<StockItem> _$stockItems(Component v) => v.stockItems;
  static const Field<Component, ToMany<StockItem>> _f$stockItems = Field(
    'stockItems',
    _$stockItems,
    mode: FieldMode.member,
  );

  @override
  final MappableFields<Component> fields = const {
    #id: _f$id,
    #name: _f$name,
    #description: _f$description,
    #base64Image: _f$base64Image,
    #iconSvg: _f$iconSvg,
    #attributesJson: _f$attributesJson,
    #lowStockThreshold: _f$lowStockThreshold,
    #options: _f$options,
    #optionsList: _f$optionsList,
    #projectItem: _f$projectItem,
    #category: _f$category,
    #type: _f$type,
    #stockItems: _f$stockItems,
  };

  static Component _instantiate(DecodingData data) {
    return Component(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      base64Image: data.dec(_f$base64Image),
      iconSvg: data.dec(_f$iconSvg),
      attributesJson: data.dec(_f$attributesJson),
      lowStockThreshold: data.dec(_f$lowStockThreshold),
      options: data.dec(_f$options),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Component fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Component>(map);
  }

  static Component fromJson(String json) {
    return ensureInitialized().decodeJson<Component>(json);
  }
}

mixin ComponentMappable {
  String toJson() {
    return ComponentMapper.ensureInitialized().encodeJson<Component>(
      this as Component,
    );
  }

  Map<String, dynamic> toMap() {
    return ComponentMapper.ensureInitialized().encodeMap<Component>(
      this as Component,
    );
  }
}

