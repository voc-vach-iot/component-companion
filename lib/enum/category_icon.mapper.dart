// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'category_icon.dart';

class CategoryIconMapper extends EnumMapper<CategoryIcon> {
  CategoryIconMapper._();

  static CategoryIconMapper? _instance;
  static CategoryIconMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CategoryIconMapper._());
    }
    return _instance!;
  }

  static CategoryIcon fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  CategoryIcon decode(dynamic value) {
    switch (value) {
      case r'cpu':
        return CategoryIcon.cpu;
      case r'battery':
        return CategoryIcon.battery;
      case r'monitor':
        return CategoryIcon.monitor;
      case r'chip':
        return CategoryIcon.chip;
      case r'wifi':
        return CategoryIcon.wifi;
      case r'box':
        return CategoryIcon.box;
      case r'share':
        return CategoryIcon.share;
      case r'zap':
        return CategoryIcon.zap;
      case r'thermometer':
        return CategoryIcon.thermometer;
      case r'toggle':
        return CategoryIcon.toggle;
      case r'database':
        return CategoryIcon.database;
      case r'bluetooth':
        return CategoryIcon.bluetooth;
      case r'server':
        return CategoryIcon.server;
      case r'speaker':
        return CategoryIcon.speaker;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(CategoryIcon self) {
    switch (self) {
      case CategoryIcon.cpu:
        return r'cpu';
      case CategoryIcon.battery:
        return r'battery';
      case CategoryIcon.monitor:
        return r'monitor';
      case CategoryIcon.chip:
        return r'chip';
      case CategoryIcon.wifi:
        return r'wifi';
      case CategoryIcon.box:
        return r'box';
      case CategoryIcon.share:
        return r'share';
      case CategoryIcon.zap:
        return r'zap';
      case CategoryIcon.thermometer:
        return r'thermometer';
      case CategoryIcon.toggle:
        return r'toggle';
      case CategoryIcon.database:
        return r'database';
      case CategoryIcon.bluetooth:
        return r'bluetooth';
      case CategoryIcon.server:
        return r'server';
      case CategoryIcon.speaker:
        return r'speaker';
    }
  }
}

extension CategoryIconMapperExtension on CategoryIcon {
  String toValue() {
    CategoryIconMapper.ensureInitialized();
    return MapperContainer.globals.toValue<CategoryIcon>(this) as String;
  }
}

