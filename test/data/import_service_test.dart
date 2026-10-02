import 'dart:io';

import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  test("đọc JSON dạng BOM (clean_name / variant)", () {
    final rows = ImportService.parse('''[
      {"raw_name": "Bộ 50 Công Tắc Rung", "clean_name": "Công tắc rung SW-18010P", "variant": "10PCS"},
      {"raw_name": "x", "clean_name": "Tụ hóa 100uF", "variant": ""}
    ]''');
    expect(rows.map((r) => r.name), [
      "Công tắc rung SW-18010P",
      "Tụ hóa 100uF",
    ]);
    expect(rows.first.packName, "10PCS");
  });

  test("đọc file mẫu: thuộc tính, giá có dấu chấm", () {
    final rows = ImportService.parse(ImportService.templateCsv());
    expect(rows, hasLength(4));
    expect(rows.first.attributes, {"Điện áp": "5V", "Kiểu": "Active"});
    expect(rows.first.packName, "Gói 5 cái");
    expect(rows.first.units, 5);
    expect(rows.first.price, 12000);
    expect(rows.first.shop, "Linh kiện ABC");

    final dot = ImportService.parse("Tên;Giá gói\nTrở;25.000đ").single;
    expect(dot.price, 25000);
  });

  test("báo lỗi khi không có cột tên", () {
    expect(() => ImportService.parse("a,b\n1,2"), throwsA(anything));
  });

  group("ghi vào DB", () {
    late ObjectboxService db;
    late Directory dir;
    setUp(() async => (db, dir) = await openTestDb());
    tearDown(() => closeTestDb(db, dir));

    test(
      "tạo linh kiện + biến thể, gộp tuỳ chọn cùng giá cho nhiều biến thể, cộng kho",
      () {
        final passive = db.get<Category>().put(
          Category(name: "Thụ động", colorValue: 0xFF000000, keywords: ["còi"]),
        );
        final service = ImportService();
        final plans = service.plan(
          ImportService.parse(ImportService.templateCsv()),
        );
        expect(plans.first.categoryId, passive);

        final result = service.apply(plans, addToStock: true);
        expect(result.created, 3);
        expect(result.variantsCreated, 4); // 2 còi + 1 trở + 1 mặc định ESP32

        final buzzer = db.get<Component>().getAll().firstWhere(
          (c) => c.name.startsWith("Còi"),
        );
        expect(buzzer.attributes.map((a) => a.name), ["Điện áp", "Kiểu"]);
        expect(buzzer.variants, hasLength(2));
        // 2 dòng cùng shop + phân loại + giá => 1 tuỳ chọn gắn 2 biến thể
        final offer = buzzer.options.single;
        expect(offer.variants, hasLength(2));
        expect(offer.shopName, "Linh kiện ABC");
        final v5 = buzzer.variants.firstWhere(
          (v) => v.selection["Điện áp"] == "5V",
        );
        expect(v5.stock, 5);

        final esp = db.get<Component>().getAll().firstWhere(
          (c) => c.name.startsWith("ESP32"),
        );
        expect(esp.variants.single.isDefault, isTrue);
        expect(esp.variants.single.stock, 3);
        expect(db.get<Shop>().count(), 2);

        // Nhập lại không tạo trùng tuỳ chọn / biến thể
        service.apply(
          service.plan(ImportService.parse(ImportService.templateCsv())),
        );
        expect(db.get<ComponentOption>().count(), 3);
        expect(db.get<Component>().get(buzzer.id)!.variants, hasLength(2));
      },
    );
  });
}
