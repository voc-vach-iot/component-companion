import 'dart:io';

import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/unit.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/bulk_edit_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  Component comp(int id) => db.get<Component>().get(id)!;
  ComponentVariant variant(int id) => db.get<ComponentVariant>().get(id)!;

  group("đơn vị", () {
    test("format / parse", () {
      expect(QuantityUnit.meter.formatNumber(150), "1,5");
      expect(QuantityUnit.meter.format(1000), "10 mét");
      expect(QuantityUnit.piece.format(12), "12 cái");
      expect(QuantityUnit.meter.parse("1,5"), 150);
      expect(QuantityUnit.meter.parse("1.5m"), 150);
      expect(QuantityUnit.meter.parse("50cm"), 50);
      expect(QuantityUnit.kilogram.parse("250g"), 250);
      expect(QuantityUnit.kilogram.parse("0,25"), 250);
      expect(QuantityUnit.liter.parse("500ml"), 500);
      expect(QuantityUnit.piece.parse("7"), 7);
      expect(QuantityUnit.piece.parse("abc"), isNull);
      expect(QuantityUnit.meter.parse("2kg"), isNull);
      expect(QuantityUnit.of("kg"), QuantityUnit.kilogram);
      expect(QuantityUnit.of(""), QuantityUnit.piece);
    });

    test("đổi cái -> mét nhân hệ số, hoàn tác khôi phục", () async {
      final (c, variants) = await createComponent("Dây 22AWG");
      final v = variants[""]!;
      v.stock = 12;
      v.incoming = 3;
      v.lowStockThreshold = 2;
      db.get<ComponentVariant>().put(v);
      final optionId = await addOffer(
        c,
        [v],
        name: "Cuộn 10",
        units: 10,
        price: 50000,
      );
      final item = ProjectItem(quantity: 4)
        ..component.targetId = c.id
        ..variant.targetId = v.id;
      db.get<ProjectItem>().put(item);

      final undo = BulkEditService().changeUnit([c.id], QuantityUnit.meter);

      expect(comp(c.id).unit, "m");
      expect(variant(v.id).stock, 1200);
      expect(variant(v.id).incoming, 300);
      expect(variant(v.id).lowStockThreshold, 200);
      expect(db.get<ComponentOption>().get(optionId)!.unitsPerPack, 1000);
      expect(db.get<ProjectItem>().get(item.id)!.quantity, 400);
      // Giá gói giữ nguyên, đơn giá hiển thị theo mét
      final o = db.get<ComponentOption>().get(optionId)!;
      expect(o.pricePerPack, 50000);
      final text = o.unit.pricePer(o.pricePerUnit);
      expect(text, contains("5.000"));
      expect(text, endsWith("/mét"));

      undo.run();
      expect(comp(c.id).unit, "");
      expect(variant(v.id).stock, 12);
      expect(db.get<ComponentOption>().get(optionId)!.unitsPerPack, 10);
      expect(db.get<ProjectItem>().get(item.id)!.quantity, 4);
    });

    test("đổi sang đơn vị đang dùng: không làm gì", () async {
      final (c, v) = await createComponent("Trở");
      final variantA = v[""]!..stock = 5;
      db.get<ComponentVariant>().put(variantA);
      BulkEditService().changeUnit([c.id], QuantityUnit.piece);
      expect(variant(variantA.id).stock, 5);
    });
  });

  group("đổi tên linh kiện", () {
    test("đổi + hoàn tác", () async {
      final (a, _) = await createComponent("A");
      final (b, _) = await createComponent("B");
      final undo = BulkEditService().renameComponents({a.id: "A2", b.id: "B2"});
      expect(comp(a.id).name, "A2");
      expect(comp(b.id).name, "B2");
      undo.run();
      expect(comp(a.id).name, "A");
    });

    test(
      "trùng tên khác linh kiện hoặc trùng nhau thì báo lỗi, không đổi gì",
      () async {
        final (a, _) = await createComponent("A");
        final (b, _) = await createComponent("B");
        await createComponent("C");
        expect(
          () => BulkEditService().renameComponents({a.id: "C"}),
          throwsA(isA<EntityAlreadyExistsException>()),
        );
        expect(
          () => BulkEditService().renameComponents({a.id: "X", b.id: "X"}),
          throwsA(isA<EntityAlreadyExistsException>()),
        );
        expect(comp(a.id).name, "A");
      },
    );

    test("hoán đổi tên giữa các linh kiện trong đợt được phép", () async {
      final (a, _) = await createComponent("A");
      final (b, _) = await createComponent("B");
      BulkEditService().renameComponents({a.id: "B", b.id: "A"});
      expect(comp(a.id).name, "B");
      expect(comp(b.id).name, "A");
    });
  });

  group("đổi tên tuỳ chọn mua", () {
    test("đổi + hoàn tác", () async {
      final (c, v) = await createComponent("Trở");
      final id = await addOffer(
        c,
        [v[""]!],
        name: "Phân loại: 100 chiếc",
        units: 100,
        price: 9000,
      );
      final undo = BulkEditService().renameOptions({id: "Gói 100 cái"});
      expect(db.get<ComponentOption>().get(id)!.name, "Gói 100 cái");
      undo.run();
      expect(db.get<ComponentOption>().get(id)!.name, "Phân loại: 100 chiếc");
    });
  });

  group("giá trị thuộc tính nhiều biến thể", () {
    final attrs = [
      const VariantAttribute("Điện áp", ["3V", "5V"]),
      const VariantAttribute("Kiểu", ["DIP", "SMD"]),
    ];

    test(
      "đặt giá trị mới, thêm vào thuộc tính nếu chưa có, hoàn tác được",
      () async {
        final (c, vs) = await createComponent(
          "IC",
          attributes: attrs,
          variants: [
            {"Điện áp": "3V", "Kiểu": "DIP"},
            {"Điện áp": "3V", "Kiểu": "SMD"},
          ],
        );
        final ids = [for (final v in vs.values) v.id];
        final svc = BulkEditService();

        final plan = svc.previewAssign(ids, "Điện áp", "12V");
        expect(plan.changed, 2);
        expect(plan.merged, 0);

        final r = svc.assignAttribute(ids, "Điện áp", "12V");
        expect(r.undo, isNotNull);
        expect(comp(c.id).attributes.first.values, ["3V", "5V", "12V"]);
        expect(
          db
              .get<ComponentVariant>()
              .getMany(ids)
              .map((v) => v!.selection["Điện áp"]),
          everyElement("12V"),
        );

        r.undo!.run();
        expect(comp(c.id).attributes.first.values, ["3V", "5V"]);
        expect(
          db
              .get<ComponentVariant>()
              .getMany(ids)
              .map((v) => v!.selection["Điện áp"]),
          everyElement("3V"),
        );
      },
    );

    test(
      "trùng tổ hợp thì gộp biến thể, cộng tồn kho, không hoàn tác",
      () async {
        final (c, vs) = await createComponent(
          "IC2",
          attributes: attrs,
          variants: [
            {"Điện áp": "3V", "Kiểu": "DIP"},
            {"Điện áp": "5V", "Kiểu": "DIP"},
          ],
        );
        final a = vs["3V · DIP"]!..stock = 4;
        final b = vs["5V · DIP"]!..stock = 6;
        db.get<ComponentVariant>().putMany([a, b]);

        final svc = BulkEditService();
        expect(svc.previewAssign([a.id], "Điện áp", "5V").merged, 1);
        final r = svc.assignAttribute([a.id], "Điện áp", "5V");
        expect(r.undo, isNull);

        final left = comp(c.id).variants.toList();
        expect(left.length, 1);
        expect(left.single.stock, 10);
      },
    );

    test("linh kiện không có thuộc tính đó thì bỏ qua", () async {
      final (_, vs) = await createComponent("Trở");
      final plan = BulkEditService().previewAssign(
        [vs[""]!.id],
        "Điện áp",
        "5V",
      );
      expect(plan.skipped, 1);
      expect(plan.changed, 0);
    });
  });

  test("gán danh mục / ngưỡng hàng loạt", () async {
    final (c, vs) = await createComponent("Trở");
    final undo = BulkEditService().assign([c.id], threshold: 7);
    expect(variant(vs[""]!.id).lowStockThreshold, 7);
    undo.run();
    expect(variant(vs[""]!.id).lowStockThreshold, 0);
  });

  test("resyncVariants có sẵn", () {
    expect(ComponentRepository().resyncVariants, isNotNull);
  });
}
