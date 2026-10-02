import 'dart:io';

import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/stock_item.dart';
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
    expect(rows.first.variant, "10PCS");
  });

  test("đọc CSV tiêu đề tiếng Việt có dấu, giá có dấu chấm", () {
    final rows = ImportService.parse(
      "Tên sản phẩm;Phân loại;Giá;Số cái;Số lượng;Shop;Link\n"
      "Điện trở 10K 1206;Gói 100;25.000đ;100;2;Shop A;https://a\n",
    );
    final r = rows.single;
    expect(r.name, "Điện trở 10K 1206");
    expect(r.variant, "Gói 100");
    expect(r.price, 25000);
    expect(r.units, 100);
    expect(r.quantity, 2);
    expect(r.shop, "Shop A");
    expect(r.link, "https://a");
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
      "tạo linh kiện, gộp dòng trùng tên, thêm tuỳ chọn, cộng kho, nhận diện danh mục",
      () {
        final passive = db.get<Category>().put(
          Category(
            name: "Thụ động",
            colorValue: 0xFF000000,
            keywords: ["điện trở"],
          ),
        );
        final existing = db.get<Component>().put(
          Component(name: "Tụ hóa 100uF"),
        );

        final service = ImportService();
        final plans = service.plan(
          ImportService.parse(
            "Tên,Phân loại,Giá,Số cái,Số lượng,Shop\n"
            "Điện trở 10K 1206,Gói 100,25000,100,2,Shop A\n"
            "Điện trở 10K 1206,Gói 50,15000,50,0,Shop B\n"
            "Tụ hóa 100uF,Gói 10,8000,10,1,Shop A\n",
          ),
        );
        expect(plans[0].categoryId, passive);
        expect(plans[0].existing, isNull);
        expect(plans[2].existing?.id, existing);

        final result = service.apply(plans, addToStock: true);
        expect(result.created, 1);
        expect(result.optionsAdded, 3);

        final resistor = db.get<Component>().getAll().firstWhere(
          (c) => c.name == "Điện trở 10K 1206",
        );
        expect(
          resistor.options.map((o) => o.shop),
          unorderedEquals(["Shop A", "Shop B"]),
        );
        expect(resistor.stockTotal, 200);
        expect(db.get<Component>().get(existing)!.stockTotal, 10);

        // Nhập lại lần nữa không tạo trùng tuỳ chọn
        service.apply(
          service.plan(
            ImportService.parse(
              "Tên,Phân loại,Giá,Số cái,Shop\nĐiện trở 10K 1206,Gói 100,25000,100,Shop A\n",
            ),
          ),
        );
        expect(db.get<ComponentOption>().count(), 3);
        expect(db.get<StockItem>().count(), 2);
      },
    );
  });
}
