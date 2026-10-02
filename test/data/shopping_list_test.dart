import 'dart:io';

import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/data/project_item_repository.dart';
import 'package:component_companion/data/stock_repository.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  test(
    "gộp nhu cầu theo biến thể, trừ kho, quy ra gói, chọn shop rẻ",
    () async {
      final buttonId = await ComponentRepository().add(
        Component(name: "Nút nhấn")
          ..attributes = const [
            VariantAttribute("Màu", ["Đỏ", "Xanh"]),
          ],
      );
      final optionRepo = ComponentOptionRepository();
      final shopA = await optionRepo.add(
        ComponentOption(
          name: "Gói 10",
          unitsPerPack: 10,
          pricePerPack: 30000,
          shop: "Shop A",
        )..component.targetId = buttonId,
      );
      final shopB = await optionRepo.add(
        ComponentOption(
          name: "Gói 5",
          unitsPerPack: 5,
          pricePerPack: 10000,
          shop: "Shop B",
        )..component.targetId = buttonId,
      );
      await StockRepository().adjust(buttonId, {"Màu": "Đỏ"}, 3);

      final p1 = db.get<Project>().put(Project(name: "Robot"));
      final p2 = db.get<Project>().put(Project(name: "Đèn"));
      ProjectItem item(int project, String color, int qty) =>
          ProjectItem(quantity: qty)
            ..variant = {"Màu": color}
            ..component.targetId = buttonId
            ..componentOption.targetId = shopA
            ..project.targetId = project;
      db.get<ProjectItem>().putMany([
        item(p1, "Đỏ", 8),
        item(p2, "Đỏ", 4),
        item(p2, "Xanh", 2),
      ]);

      final entries = [
        for (final i in db.get<ProjectItem>().getAll())
          (item: i, usedIn: i.project.target!.name),
      ];

      final lines = ShoppingList.build(entries);
      final red = lines.firstWhere((l) => l.variant["Màu"] == "Đỏ");
      expect(red.needed, 12);
      expect(red.inStock, 3);
      expect(red.shortage, 9);
      expect(red.packs, 1); // gói 10 của Shop A (tuỳ chọn đang chọn)
      expect(red.cost, 30000);
      expect(red.usedIn, unorderedEquals(["Robot", "Đèn"]));

      // Dùng giá rẻ nhất: Shop B 2.000đ/cái => 9 cái cần 2 gói 5
      final cheap = ShoppingList.build(entries, useCheapest: true);
      final redCheap = cheap.firstWhere((l) => l.variant["Màu"] == "Đỏ");
      expect(redCheap.option!.id, shopB);
      expect(redCheap.packs, 2);
      expect(redCheap.cost, 20000);

      final groups = ShoppingList.byShop(cheap);
      expect(groups.single.shop, "Shop B");
      expect(groups.single.total, 20000 + 10000); // đỏ 2 gói + xanh 1 gói

      // Không trừ kho
      final noStock = ShoppingList.build(entries, subtractStock: false);
      expect(noStock.firstWhere((l) => l.variant["Màu"] == "Đỏ").shortage, 12);
    },
  );

  test(
    "dùng giá rẻ nhất cho cả dự án chỉ chọn tuỳ chọn áp dụng cho biến thể",
    () async {
      final id = await ComponentRepository().add(
        Component(name: "Vít M3")
          ..attributes = const [
            VariantAttribute("Dài", ["5mm", "10mm"]),
          ],
      );
      final repo = ComponentOptionRepository();
      final normal = await repo.add(
        ComponentOption(name: "Gói 20", unitsPerPack: 20, pricePerPack: 20000)
          ..component.targetId = id,
      );
      // Rẻ hơn nhưng chỉ bán loại 5mm
      final only5 = await repo.add(
        ComponentOption(
            name: "Gói 50 (5mm)",
            unitsPerPack: 50,
            pricePerPack: 25000,
          )
          ..availability = {
            "Dài": ["5mm"],
          }
          ..component.targetId = id,
      );
      final projectId = db.get<Project>().put(Project(name: "Hộp"));
      db.get<ProjectItem>().putMany([
        for (final len in ["5mm", "10mm"])
          ProjectItem(quantity: 10)
            ..variant = {"Dài": len}
            ..component.targetId = id
            ..componentOption.targetId = normal
            ..project.targetId = projectId,
      ]);

      final result = await ProjectItemRepository().useCheapest(projectId);
      expect(result.switched, 1);
      expect(result.saving, closeTo(10 * (1000 - 500), 0.01));
      final items = db.get<ProjectItem>().getAll();
      expect(
        items
            .firstWhere((i) => i.variant["Dài"] == "5mm")
            .componentOption
            .targetId,
        only5,
      );
      expect(
        items
            .firstWhere((i) => i.variant["Dài"] == "10mm")
            .componentOption
            .targetId,
        normal,
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
