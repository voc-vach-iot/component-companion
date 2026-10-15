import 'dart:convert';
import 'dart:io';

import 'package:component_companion/data/project_group_repository.dart';
import 'package:component_companion/data/project_option_repository.dart';
import 'package:component_companion/data/project_repository.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/project_group_migration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  // Repository giữ box của DB đang mở => tạo lại sau mỗi lần mở DB test
  late ProjectGroupRepository groups;
  late ProjectOptionRepository options;
  setUp(() {
    groups = ProjectGroupRepository();
    options = ProjectOptionRepository();
  });

  /// Dự án "Robot": 1 linh kiện chung (2 cái), nhóm MCU (ESP32 | STM32) và
  /// nhóm Pin (1000mAh | 2000mAh), mỗi phương án 1 linh kiện giá khác nhau.
  Future<({int projectId, Map<String, int> option})> seed() async {
    final (component, variants) = await createComponent("Linh kiện");
    final variant = variants[""]!;
    var shop = 0;
    // Mỗi giá 1 shop để không trùng tuỳ chọn mua
    Future<int> offer(int price) => addOffer(
      component,
      [variant],
      name: "1 cái",
      units: 1,
      price: price,
      shop: "Shop ${++shop}",
    );

    final projectId = db.get<Project>().put(Project(name: "Robot"));
    final commonOffer = await offer(1000);
    db.get<ProjectItem>().put(
      ProjectItem(quantity: 2)
        ..component.targetId = component.id
        ..variant.targetId = variant.id
        ..componentOption.targetId = commonOffer
        ..project.targetId = projectId,
    );

    final option = <String, int>{};
    for (final (group, names, prices) in [
      ("MCU", ["ESP32", "STM32"], [100000, 80000]),
      ("Pin", ["1000mAh", "2000mAh"], [30000, 50000]),
    ]) {
      final groupId = await groups.add(
        ProjectGroup(name: group)..project.targetId = projectId,
        names,
      );
      for (final o in groups.get(groupId)!.sortedOptions) {
        option[o.name] = o.id;
        final price = prices[names.indexOf(o.name)];
        db.get<ProjectItem>().put(
          ProjectItem(quantity: 1)
            ..component.targetId = component.id
            ..variant.targetId = variant.id
            ..componentOption.targetId = await offer(price)
            ..projectOption.targetId = o.id,
        );
      }
    }
    return (projectId: projectId, option: option);
  }

  Project project(int id) => db.get<Project>().get(id)!;

  test("thêm phương án mới tạo (chưa gắn store) không lỗi", () async {
    final projectId = db.get<Project>().put(Project(name: "Robot"));
    final groupId = await groups.add(
      ProjectGroup(name: "MCU")..project.targetId = projectId,
      const [],
    );
    final id = await options.add(
      ProjectOption(name: "STM32")..group.targetId = groupId,
    );
    final group = groups.get(groupId)!;
    expect(group.sortedOptions.map((o) => o.name), ["Phương án 1", "STM32"]);
    expect(group.selectedOption?.name, "Phương án 1");
    expect(db.get<ProjectOption>().get(id)!.project.targetId, projectId);
  });

  test("tên nhóm / phương án trùng bị chặn", () async {
    final s = await seed();
    expect(
      () => groups.add(
        ProjectGroup(name: "mcu")..project.targetId = s.projectId,
        const [],
      ),
      throwsA(isA<EntityAlreadyExistsException>()),
    );
    final mcu = groups.byProject(s.projectId).first;
    expect(
      () => options.add(ProjectOption(name: "esp32")..group.targetId = mcu.id),
      throwsA(isA<EntityAlreadyExistsException>()),
    );
  });

  test(
    "cấu hình = chung + phương án đang chọn mỗi nhóm, 2x2 không cần 4 bản",
    () async {
      final s = await seed();
      // Mặc định phương án đầu: ESP32 + 1000mAh
      expect(project(s.projectId).configurationPrice, 2000 + 100000 + 30000);

      await groups.select(s.option["STM32"]!);
      await groups.select(s.option["2000mAh"]!);
      final p = project(s.projectId);
      expect(p.configurationPrice, 2000 + 80000 + 50000);
      expect(p.configurationItems, hasLength(3));
      expect(p.configurationEntries.map((e) => e.usedIn).toSet(), {
        "Robot",
        "Robot · MCU: STM32",
        "Robot · Pin: 2000mAh",
      });
    },
  );

  test("khoảng giá các cấu hình", () async {
    final s = await seed();
    final range = project(s.projectId).configurationPriceRange();
    expect(range.min, 2000 + 80000 + 30000);
    expect(range.max, 2000 + 100000 + 50000);
  });

  test("nhân bản phương án kèm linh kiện, xoá phương án đang chọn", () async {
    final s = await seed();
    final copyId = await options.duplicate(s.option["ESP32"]!);
    final copy = db.get<ProjectOption>().get(copyId)!;
    expect(copy.name, "ESP32 (bản sao)");
    expect(copy.items, hasLength(1));
    expect(copy.items.first.quantity, 1);

    await groups.select(copyId);
    await options.delete(copyId);
    final mcu = groups.byProject(s.projectId).first;
    expect(mcu.selected.targetId, s.option["ESP32"]);
  });

  test("đổi thứ tự nhóm", () async {
    final s = await seed();
    final pin = groups.byProject(s.projectId).last;
    await groups.move(pin.id, -1);
    expect(groups.byProject(s.projectId).map((g) => g.name), ["Pin", "MCU"]);
  });

  test("xoá dự án xoá kèm nhóm, phương án, linh kiện", () async {
    final s = await seed();
    await ProjectRepository().delete(s.projectId);
    expect(db.get<ProjectGroup>().count(), 0);
    expect(db.get<ProjectOption>().count(), 0);
    expect(db.get<ProjectItem>().count(), 0);
  });

  test("hoàn tác xoá nhóm: khôi phục phương án, linh kiện, lựa chọn", () async {
    final s = await seed();
    await groups.select(s.option["STM32"]!);
    final mcu = groups.byProject(s.projectId).first;
    final transfer = DataTransferService();
    final snapshot = transfer.snapshot(projectGroupIds: [mcu.id]);
    await groups.delete(mcu.id);
    expect(project(s.projectId).configurationPrice, 2000 + 30000);

    transfer.restore(jsonDecode(jsonEncode(snapshot)));
    // Giữ nguyên thứ tự nhóm
    final restored = groups.byProject(s.projectId).first;
    expect(restored.name, "MCU");
    expect(restored.selectedOption?.name, "STM32");
    expect(project(s.projectId).configurationPrice, 2000 + 80000 + 30000);
  });

  test(
    "hoàn tác xoá phương án đang chọn: nhóm chọn lại phương án đó",
    () async {
      final s = await seed();
      final transfer = DataTransferService();
      final id = s.option["ESP32"]!;
      final snapshot = transfer.snapshot(projectOptionIds: [id]);
      await options.delete(id);
      expect(groups.byProject(s.projectId).first.selectedOption?.name, "STM32");

      transfer.restore(jsonDecode(jsonEncode(snapshot)));
      final mcu = groups.byProject(s.projectId).first;
      expect(mcu.selectedOption?.name, "ESP32");
      expect(mcu.selectedOption?.items, hasLength(1));
    },
  );

  test("sao lưu rồi khôi phục giữ nhóm và lựa chọn", () async {
    final s = await seed();
    await groups.select(s.option["2000mAh"]!);
    final transfer = DataTransferService();
    final data = jsonDecode(jsonEncode(transfer.exportAll()));
    transfer.replaceAll(data);

    final p = db.get<Project>().getAll().single;
    expect(p.sortedGroups.map((g) => g.name), ["MCU", "Pin"]);
    expect(p.sortedGroups.last.selectedOption?.name, "2000mAh");
    expect(p.configurationPrice, 2000 + 100000 + 50000);
  });

  test("phiên bản cũ (chưa có nhóm) được gom vào nhóm 'Phiên bản'", () async {
    final projectId = db.get<Project>().put(Project(name: "Đèn"));
    db.get<ProjectOption>().putMany([
      ProjectOption(name: "Bản thường")..project.targetId = projectId,
      ProjectOption(name: "Bản pin")..project.targetId = projectId,
    ]);

    expect(ProjectGroupMigration().run(), 2);
    expect(ProjectGroupMigration().run(), 0);
    final group = db.get<Project>().get(projectId)!.sortedGroups.single;
    expect(group.name, ProjectGroupMigration.legacyGroupName);
    expect(group.sortedOptions.map((o) => o.name), ["Bản thường", "Bản pin"]);
    expect(group.selectedOption?.name, "Bản thường");
  });

  test("file sao lưu v2 (chưa có nhóm) khôi phục thành nhóm", () async {
    final s = await seed();
    final data = jsonDecode(jsonEncode(DataTransferService().exportAll()));
    data["version"] = 2;
    data.remove("projectGroups");
    for (final o in data["projectOptions"] as List) {
      (o as Map).remove("groupId");
    }
    DataTransferService().replaceAll(data);

    final p = db.get<Project>().getAll().single;
    expect(p.sortedGroups.single.options, hasLength(4));
    expect(s.option, hasLength(4));
  });
}
