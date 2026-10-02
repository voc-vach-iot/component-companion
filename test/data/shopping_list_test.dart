import 'dart:io';

import 'package:component_companion/data/project_item_repository.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/util/purchase_planner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  group("PurchasePlanner", () {
    late List<ComponentOption> offers;

    setUp(() async {
      final (c, v) = await createComponent("Trở 10K");
      final variant = v[""]!;
      await addOffer(
        c,
        [variant],
        name: "1 cái",
        units: 1,
        price: 1000,
        shop: "A",
      );
      await addOffer(
        c,
        [variant],
        name: "Gói 10",
        units: 10,
        price: 8000,
        shop: "A",
      );
      await addOffer(
        c,
        [variant],
        name: "Gói 100",
        units: 100,
        price: 50000,
        shop: "B",
      );
      offers = db.get<ComponentVariant>().get(variant.id)!.options.toList();
    });

    ComponentOption named(String name) =>
        offers.firstWhere((o) => o.name == name);

    test("cần ít thì gói nhỏ rẻ hơn dù đơn giá cao hơn", () {
      expect(PurchasePlanner.bestSingle(offers, 3)!.name, "1 cái"); // 3k vs 8k
      expect(PurchasePlanner.bestSingle(offers, 9)!.name, "Gói 10"); // 8k vs 9k
      expect(
        PurchasePlanner.bestSingle(offers, 90)!.name,
        "Gói 100",
      ); // 50k vs 72k
    });

    test("kết hợp nhiều gói trong cùng 1 shop", () {
      final plan = PurchasePlanner.bestPlan(offers, 12, onlyShop: "A");
      expect(plan.label, "1 × Gói 10 + 2 × 1 cái");
      expect(plan.cost, 10000);
      expect(plan.units, 12);
    });

    test("so sánh giữa các shop, mỗi phương án chỉ 1 shop", () {
      final plan = PurchasePlanner.bestPlan(offers, 70);
      // A: 7 gói 10 = 56k; B: 1 gói 100 = 50k
      expect(plan.shopName, "B");
      expect(plan.cost, 50000);
      expect(named("Gói 100").shopName, "B");
    });
  });

  test(
    "danh sách cần mua theo biến thể: trừ kho, kết hợp gói, đúng biến thể",
    () async {
      final (c, v) = await createComponent(
        "Còi chip",
        attributes: const [
          VariantAttribute("Kiểu", ["Active", "Passive"]),
        ],
        variants: const [
          {"Kiểu": "Active"},
          {"Kiểu": "Passive"},
        ],
      );
      final active = v["Active"]!..stock = 3;
      final passive = v["Passive"]!;
      db.get<ComponentVariant>().put(active);
      // Passive rẻ hơn nhiều nhưng không được đề xuất cho dự án cần Active
      final activeOffer = await addOffer(
        c,
        [active],
        name: "Gói 5",
        units: 5,
        price: 15000,
        shop: "A",
      );
      await addOffer(
        c,
        [active],
        name: "1 cái",
        units: 1,
        price: 3500,
        shop: "A",
      );
      await addOffer(
        c,
        [passive],
        name: "Gói 5",
        units: 5,
        price: 5000,
        shop: "A",
      );

      final p1 = db.get<Project>().put(Project(name: "Robot"));
      final p2 = db.get<Project>().put(Project(name: "Đèn"));
      db.get<ProjectItem>().putMany([
        for (final (project, qty) in [(p1, 8), (p2, 2)])
          ProjectItem(quantity: qty)
            ..component.targetId = c.id
            ..variant.targetId = active.id
            ..componentOption.targetId = activeOffer
            ..project.targetId = project,
      ]);

      final entries = [
        for (final i in db.get<ProjectItem>().getAll())
          (item: i, usedIn: i.project.target!.name),
      ];
      final line = ShoppingList.build(entries).single;
      expect(line.variantLabel, "Active");
      expect(line.needed, 10);
      expect(line.shortage, 7);
      // 7 cái: 1 gói 5 + 2 cái lẻ = 15k + 7k = 22k (rẻ hơn 2 gói 5 = 30k)
      expect(line.plan.label, "1 × Gói 5 + 2 × 1 cái");
      expect(line.cost, 22000);
      expect(
        line.plan.parts.every((p) => p.option.appliesTo(active.id)),
        isTrue,
      );

      // Không trừ kho
      final noStock = ShoppingList.build(entries, subtractStock: false).single;
      expect(noStock.shortage, 10);
      expect(noStock.cost, 30000);
    },
  );

  test(
    "dùng giá rẻ nhất theo số lượng cần, chỉ trong tuỳ chọn của đúng biến thể",
    () async {
      final (c, v) = await createComponent(
        "Còi chip",
        attributes: const [
          VariantAttribute("Kiểu", ["Active", "Passive"]),
        ],
        variants: const [
          {"Kiểu": "Active"},
          {"Kiểu": "Passive"},
        ],
      );
      final pack = await addOffer(
        c,
        [v["Active"]!],
        name: "Gói 10",
        units: 10,
        price: 20000,
        shop: "A",
      );
      final single = await addOffer(
        c,
        [v["Active"]!],
        name: "1 cái",
        units: 1,
        price: 2500,
        shop: "B",
      );
      await addOffer(
        c,
        [v["Passive"]!],
        name: "1 cái",
        units: 1,
        price: 500,
        shop: "B",
      );

      final projectId = db.get<Project>().put(Project(name: "Robot"));
      db.get<ProjectItem>().put(
        ProjectItem(quantity: 3)
          ..component.targetId = c.id
          ..variant.targetId = v["Active"]!.id
          ..componentOption.targetId = pack
          ..project.targetId = projectId,
      );

      final result = await ProjectItemRepository().useCheapest(projectId);
      expect(result.switched, 1);
      expect(result.saving, 20000 - 7500);
      expect(
        db.get<ProjectItem>().getAll().single.componentOption.targetId,
        single,
      );
    },
  );

  test("CSV mã hoá / giải mã giữ dấu phẩy, ngoặc kép, xuống dòng", () {
    final rows = [
      ["Tên", "Ghi chú"],
      ["Trở 10K, 1206", 'Loại "tốt"\nmua 2 gói'],
    ];
    expect(Csv.decode(Csv.encode(rows)), rows);
    expect(Csv.decode("a;b\n1;2"), [
      ["a", "b"],
      ["1", "2"],
    ]);
  });
}
