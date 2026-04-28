// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'category_color.dart';

class CategoryColorMapper extends EnumMapper<CategoryColor> {
  CategoryColorMapper._();

  static CategoryColorMapper? _instance;
  static CategoryColorMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CategoryColorMapper._());
    }
    return _instance!;
  }

  static CategoryColor fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  CategoryColor decode(dynamic value) {
    switch (value) {
      case r'purple':
        return CategoryColor.purple;
      case r'blue':
        return CategoryColor.blue;
      case r'pink':
        return CategoryColor.pink;
      case r'mint':
        return CategoryColor.mint;
      case r'yellow':
        return CategoryColor.yellow;
      case r'orange':
        return CategoryColor.orange;
      case r'grey':
        return CategoryColor.grey;
      case r'beige':
        return CategoryColor.beige;
      case r'teal':
        return CategoryColor.teal;
      case r'lavender':
        return CategoryColor.lavender;
      case r'peach':
        return CategoryColor.peach;
      case r'lime':
        return CategoryColor.lime;
      case r'sky':
        return CategoryColor.sky;
      case r'slate':
        return CategoryColor.slate;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(CategoryColor self) {
    switch (self) {
      case CategoryColor.purple:
        return r'purple';
      case CategoryColor.blue:
        return r'blue';
      case CategoryColor.pink:
        return r'pink';
      case CategoryColor.mint:
        return r'mint';
      case CategoryColor.yellow:
        return r'yellow';
      case CategoryColor.orange:
        return r'orange';
      case CategoryColor.grey:
        return r'grey';
      case CategoryColor.beige:
        return r'beige';
      case CategoryColor.teal:
        return r'teal';
      case CategoryColor.lavender:
        return r'lavender';
      case CategoryColor.peach:
        return r'peach';
      case CategoryColor.lime:
        return r'lime';
      case CategoryColor.sky:
        return r'sky';
      case CategoryColor.slate:
        return r'slate';
    }
  }
}

extension CategoryColorMapperExtension on CategoryColor {
  String toValue() {
    CategoryColorMapper.ensureInitialized();
    return MapperContainer.globals.toValue<CategoryColor>(this) as String;
  }
}

