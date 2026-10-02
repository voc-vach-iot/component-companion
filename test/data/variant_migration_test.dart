import 'dart:convert';
import 'dart:io';

import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/variant_migration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  /// Dữ liệu theo mô hình cũ: nút nhấn 3 màu, tồn kho theo màu, 2 tuỳ chọn
  /// (1 cho mọi màu, 1 chỉ màu đỏ), dự án dùng màu xanh.
  void seedLegacy() {
    final c = Component(name: "Nút nhấn")
      ..attributes = const [
        VariantAttribute("Màu", ["Đỏ", "Xanh", "Vàng"]),
      ];
    final cid = db.get<Component>().put(c);
    db.get<StockItem>().putMany([
      StockItem(
        quantity: 5,
        location: "A1",
        variantJson: Variants.encodeSelection({"Màu": "Đỏ"}),
      )..component.targetId = cid,
      StockItem(
        quantity: 2,
        variantJson: Variants.encodeSelection({"Màu": "Xanh"}),
      )..component.targetId = cid,
    ]);
    final all = db.get<ComponentOption>().put(
      ComponentOption(
        name: "Gói 10",
        pricePerPack: 20000,
        unitsPerPack: 10,
        legacyShopName: "Shop A",
      )..component.targetId = cid,
    );
    db.get<ComponentOption>().put(
      ComponentOption(
        name: "Gói 10 đỏ",
        pricePerPack: 12000,
        unitsPerPack: 10,
        legacyShopName: "shop a",
        legacyAvailabilityJson: Variants.encodeAvailability({
          "Màu": ["Đỏ"],
        }),
      )..component.targetId = cid,
    );
    final pid = db.get<Project>().put(Project(name: "Robot"));
    db.get<ProjectItem>().put(
      ProjectItem(
          quantity: 4,
          legacyVariantJson: Variants.encodeSelection({"Màu": "Xanh"}),
        )
        ..component.targetId = cid
        ..componentOption.targetId = all
        ..project.targetId = pid,
    );
    // Linh kiện không thuộc tính, có tồn kho cũ
    final simple = db.get<Component>().put(Component(name: "ESP32"));
    db.get<StockItem>().put(
      StockItem(quantity: 3)..component.targetId = simple,
    );
  }

  void verifyMigrated() {
    final button = db.get<Component>().getAll().firstWhere(
      (c) => c.name == "Nút nhấn",
    );
    // Biến thể lấy từ tồn kho + dự án (không tạo màu Vàng vì chưa dùng)
    final byColor = {for (final v in button.variants) v.selection["Màu"]: v};
    expect(byColor.keys, unorderedEquals(["Đỏ", "Xanh"]));
    expect(byColor["Đỏ"]!.stock, 5);
    expect(byColor["Đỏ"]!.location, "A1");
    expect(byColor["Xanh"]!.stock, 2);

    final options = {for (final o in button.options) o.name: o};
    expect(options["Gói 10"]!.variants, hasLength(2));
    expect(options["Gói 10 đỏ"]!.variants.single.selection, {"Màu": "Đỏ"});
    // "Shop A" và "shop a" => 1 shop
    expect(db.get<Shop>().count(), 1);
    expect(options.values.map((o) => o.shopName).toSet(), {"Shop A"});

    expect(db.get<ProjectItem>().getAll().single.variant.target?.selection, {
      "Màu": "Xanh",
    });

    final esp = db.get<Component>().getAll().firstWhere(
      (c) => c.name == "ESP32",
    );
    expect(esp.variants.single.isDefault, isTrue);
    expect(esp.variants.single.stock, 3);
    expect(db.get<StockItem>().count(), 0);
  }

  test("chuyển dữ liệu mô hình cũ sang biến thể", () {
    seedLegacy();
    VariantMigration().runIfNeeded();
    verifyMigrated();
    // Chạy lại không tạo trùng
    VariantMigration().run();
    expect(db.get<ComponentVariant>().count(), 3);
  });

  test("khôi phục file sao lưu định dạng v1", () {
    final v1 = {
      "format": DataTransferService.format,
      "version": 1,
      "components": [
        {
          "id": 10,
          "name": "Nút nhấn",
          "attributesJson": Variants.encodeAttributes(const [
            VariantAttribute("Màu", ["Đỏ", "Xanh", "Vàng"]),
          ]),
        },
        {"id": 11, "name": "ESP32"},
      ],
      "options": [
        {
          "id": 20,
          "componentId": 10,
          "name": "Gói 10",
          "unitsPerPack": 10,
          "pricePerPack": 20000,
          "shop": "Shop A",
        },
        {
          "id": 21,
          "componentId": 10,
          "name": "Gói 10 đỏ",
          "unitsPerPack": 10,
          "pricePerPack": 12000,
          "shop": "shop a",
          "availabilityJson": Variants.encodeAvailability({
            "Màu": ["Đỏ"],
          }),
        },
      ],
      "stockItems": [
        {
          "id": 1,
          "componentId": 10,
          "quantity": 5,
          "location": "A1",
          "variantJson": Variants.encodeSelection({"Màu": "Đỏ"}),
        },
        {
          "id": 2,
          "componentId": 10,
          "quantity": 2,
          "variantJson": Variants.encodeSelection({"Màu": "Xanh"}),
        },
        {"id": 3, "componentId": 11, "quantity": 3},
      ],
      "projects": [
        {"id": 30, "name": "Robot"},
      ],
      "projectItems": [
        {
          "id": 40,
          "quantity": 4,
          "componentId": 10,
          "componentOptionId": 20,
          "projectId": 30,
          "variantJson": Variants.encodeSelection({"Màu": "Xanh"}),
        },
      ],
    };
    final data = jsonDecode(jsonEncode(v1)) as Map<String, dynamic>;
    expect(DataTransferService.validate(data), isNull);
    DataTransferService().replaceAll(data);
    verifyMigrated();
  });
}
