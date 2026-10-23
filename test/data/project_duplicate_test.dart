import 'dart:io';

import 'package:component_companion/data/project_item_repository.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/project_duplicates.dart';
import 'package:component_companion/util/variant_finder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  group("linh kiện trùng trong dự án", () {
    late int projectId;
    late int optionId;
    late ComponentVariant esp;
    late ComponentVariant led;

    setUp(() async {
      projectId = db.get<Project>().put(Project(name: "Robot"));
      final groupId = db.get<ProjectGroup>().put(
        ProjectGroup(name: "MCU")..project.targetId = projectId,
      );
      optionId = db.get<ProjectOption>().put(
        ProjectOption(name: "ESP32")
          ..group.targetId = groupId
          ..project.targetId = projectId,
      );
      esp = (await createComponent("ESP32")).$2[""]!;
      led = (await createComponent("LED")).$2[""]!;
    });

    ProjectItem item(ComponentVariant v, int q, {bool inOption = false}) =>
        ProjectItem(quantity: q)
          ..component.targetId = v.component.targetId
          ..variant.targetId = v.id
          ..project.targetId = inOption ? 0 : projectId
          ..projectOption.targetId = inOption ? optionId : 0;

    test("tìm dòng cùng biến thể: cùng phần trước, ghi rõ nơi", () async {
      final repo = ProjectItemRepository();
      await repo.addMany([item(esp, 1, inOption: true), item(esp, 2)]);
      final existing = repo.allOfProject(projectId);
      final matches = ProjectDuplicates.matches(item(esp, 3), existing);
      expect(matches.map(ProjectDuplicates.placeOf), [
        "Linh kiện chung",
        "MCU › ESP32",
      ]);
      expect(ProjectDuplicates.matches(item(led, 1), existing), isEmpty);
      expect(repo.projectIdOf(item(esp, 1, inOption: true)), projectId);
    });

    test("gộp khi thêm: cộng số lượng, dòng khác thêm mới", () async {
      final repo = ProjectItemRepository();
      await repo.addMany([item(esp, 2)]);
      final target = repo.allOfProject(projectId).single;
      final result = await repo.addOrMerge(
        [item(esp, 3), item(led, 5)],
        mergeInto: {0: target.id},
      );
      expect(result, (added: 1, merged: 1));
      final all = repo.allOfProject(projectId);
      expect(all, hasLength(2));
      expect(db.get<ProjectItem>().get(target.id)!.quantity, 5);
    });

    test("gộp dòng trùng có sẵn + hoàn tác", () async {
      final repo = ProjectItemRepository();
      await repo.addMany([
        item(esp, 1),
        item(esp, 2),
        item(esp, 4, inOption: true),
        item(led, 1),
      ]);
      final groups = ProjectDuplicates.groups(repo.allOfProject(projectId));
      // Dòng ở phương án khác phần => không gộp
      expect(groups, hasLength(1));
      expect(groups.single.map((i) => i.quantity), [1, 2]);

      final undo = await repo.mergeDuplicates(groups);
      var all = repo.allOfProject(projectId);
      expect(all, hasLength(3));
      expect(
        all
            .where(
              (i) =>
                  i.variant.targetId == esp.id && i.projectOption.targetId == 0,
            )
            .single
            .quantity,
        3,
      );

      await repo.undoMerge(undo);
      all = repo.allOfProject(projectId);
      expect(all, hasLength(4));
      expect(ProjectDuplicates.groups(all).single.map((i) => i.quantity), [
        1,
        2,
      ]);
    });
  });

  test("lọc biến thể theo khoảng thông số + giá / đơn vị", () async {
    final (pin, v) = await createComponent(
      "Pin Li-ion",
      attributes: [
        VariantAttribute("Dung lượng", ["2000mAh", "2.6Ah", "3500mAh"]),
        VariantAttribute("Loại", ["18650", "21700"]),
      ],
      variants: [
        {"Dung lượng": "2000mAh", "Loại": "18650"},
        {"Dung lượng": "2.6Ah", "Loại": "18650"},
        {"Dung lượng": "3500mAh", "Loại": "21700"},
      ],
    );
    await addOffer(
      pin,
      [v["2000mAh · 18650"]!],
      name: "1 cái",
      units: 1,
      price: 20000,
    );
    await addOffer(
      pin,
      [v["2.6Ah · 18650"]!],
      name: "1 cái",
      units: 1,
      price: 26000,
    );
    final all = db.get<ComponentVariant>().getAll();

    List<String> find(List<SpecCondition> conditions) => [
      for (final x in all)
        if (conditions.every((c) => VariantFinder.matches(x, c))) x.label,
    ];
    expect(
      find([const SpecCondition("dung lượng", min: "2500mAh", max: "4Ah")]),
      ["2.6Ah · 18650", "3500mAh · 21700"],
    );
    expect(
      find([
        const SpecCondition("Loại", values: {"18650"}),
      ]),
      ["2000mAh · 18650", "2.6Ah · 18650"],
    );
    // Khác đơn vị => không khớp
    expect(find([const SpecCondition("Dung lượng", min: "1V")]), isEmpty);

    final values = VariantFinder.attributeValues(all);
    expect(values.keys, ["Dung lượng", "Loại"]);
    expect(VariantFinder.isNumeric(values["Dung lượng"]!), isTrue);

    final cheap = VariantFinder.cheapest(
      db.get<ComponentVariant>().get(v["2.6Ah · 18650"]!.id)!,
    )!;
    expect(cheap.unitPrice, 26000);
    // 26000đ / 2600mAh = 10đ/mAh
    expect(
      cheap.unitPrice / VariantFinder.amountIn("2.6Ah", "mAh")!,
      closeTo(10, 1e-9),
    );
  });
}
