import 'dart:convert';
import 'dart:io';

import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/seed_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  List<Map<String, dynamic>> load(String path) =>
      (jsonDecode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
  final categorySeeds = load("assets/seed/categories.json");
  final typeSeeds = load("assets/seed/component_types.json");
  final iconsCsv = File(SeedService.iconSeedPath).readAsStringSync();

  ComponentType? type(String name) =>
      db.get<ComponentType>().getAll().where((t) => t.name == name).firstOrNull;
  String? typeOf(String component) => db
      .get<Component>()
      .getAll()
      .firstWhere((c) => c.name == component)
      .type
      .target
      ?.name;

  test("cài mới: loại theo chức năng, có danh mục, mẫu thuộc tính, icon", () {
    SeedService().apply(
      applied: 0,
      categorySeeds: categorySeeds,
      typeSeeds: typeSeeds,
      iconsCsv: iconsCsv,
    );
    expect(type("IC chân cắm (DIP)"), isNull);
    expect(type("Điện trở")!.attributeTemplate, ["Giá trị", "Đóng gói"]);
    expect(
      db.get<ComponentType>().getAll().where((t) => t.category.targetId == 0),
      isEmpty,
    );
    expect(db.get<IconAsset>().count(), greaterThan(100));
  });

  test("DB cũ: gộp loại tách theo kiểu chân, phân loại lại IC", () {
    final typeBox = db.get<ComponentType>();
    int addType(String name, List<String> keywords) =>
        typeBox.put(ComponentType(name: name, keywords: keywords));
    final dip = addType("IC chân cắm (DIP)", ["dip8", "lm358", "ne555"]);
    final sop = addType("IC dán (SOP/SOIC)", ["sop8"]);
    final tht = addType("Điện trở cắm (1/4W)", ["trở cắm"]);
    final smd = addType("Điện trở dán (SMD)", ["trở dán"]);
    addType("IC khuếch đại", ["op-amp", "lm358"]);
    db.get<Component>().putMany([
      Component(name: "LM358 DIP-8")..type.targetId = dip,
      Component(name: "Chip lạ XYZ")..type.targetId = sop,
      Component(name: "Trở 1/4W 1K")..type.targetId = tht,
      Component(name: "Trở dán 0805 10K")..type.targetId = smd,
    ]);

    SeedService().apply(applied: 2, categorySeeds: null, typeSeeds: typeSeeds);

    for (final old in SeedService.packageTypeMerges.keys) {
      expect(type(old), isNull, reason: old);
    }
    expect(typeOf("LM358 DIP-8"), "IC khuếch đại");
    expect(typeOf("Chip lạ XYZ"), SeedService.fallbackIcType);
    expect(typeOf("Trở 1/4W 1K"), "Điện trở");
    expect(typeOf("Trở dán 0805 10K"), "Điện trở");
    final resistor = type("Điện trở")!;
    expect(resistor.keywords, containsAll(["trở cắm", "trở dán"]));
    expect(resistor.attributeTemplate, ["Giá trị", "Đóng gói"]);
    for (final name in SeedService.v3NewTypes) {
      expect(type(name), isNotNull, reason: name);
    }
  });
}
