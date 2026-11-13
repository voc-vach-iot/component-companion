import 'dart:io';

import 'package:component_companion/data/power_supply_repository.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/data/tray_type_repository.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/ai/place_assistant.dart';
import 'package:component_companion/service/led/locate_planner.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/compartments.dart';
import 'package:component_companion/util/led_order.dart';
import 'package:component_companion/util/led_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;
  late StorageRepository repo;
  late int storageId;
  late TrayType a6;
  late TrayType f0;

  const blue = 0xFF0050FF;

  setUp(() async {
    (db, dir) = await openTestDb();
    repo = StorageRepository();
    final types = TrayTypeRepository();
    a6 = TrayType(
      name: "Khay A6",
      widthMm: 200,
      depthMm: 150,
      heightMm: 120,
      stackGapMm: 30,
      allowedColorsJson: "[$blue]",
      defaultColor: blue,
      minBrightness: 120,
    );
    a6.id = await types.add(a6);
    f0 = TrayType(
      name: "Khay F0",
      widthMm: 140,
      depthMm: 93,
      heightMm: 34,
      compartmentCount: 3,
      removableDividers: true,
    );
    f0.id = await types.add(f0);
    final supplyId = await PowerSupplyRepository().add(
      PowerSupply(name: "Adapter", currentA: 2.4),
    );
    storageId = await repo.add(
      Storage(name: "Kho")..powerSupply.targetId = supplyId,
    );
  });
  tearDown(() => closeTestDb(db, dir));

  ComponentVariant reload(ComponentVariant v) =>
      db.get<ComponentVariant>().get(v.id)!;

  test("tên khay tự đánh số theo loại", () async {
    final t1 = await repo.addTray(storageId, a6.id, xMm: 0, yMm: 0);
    final t2 = await repo.addTray(storageId, a6.id, xMm: 200, yMm: 0);
    final t3 = await repo.addTray(storageId, f0.id, xMm: 0, yMm: 150);
    expect(repo.tray(t1)!.label, "A6-01");
    expect(repo.tray(t2)!.label, "A6-02");
    expect(repo.tray(t3)!.label, "F0-01");
    expect(repo.tray(t1)!.frontHeightMm, 150);
  });

  test("gắn LED đã có chủ => 2 khay đổi LED cho nhau", () async {
    final t1 = await repo.addTray(storageId, a6.id, xMm: 0, yMm: 0);
    final t2 = await repo.addTray(storageId, a6.id, xMm: 200, yMm: 0);
    await repo.setLed(t1, 0);
    await repo.setLed(t2, 1);
    await repo.setLed(t2, 0);
    expect(repo.tray(t2)!.ledIndex, 0);
    expect(repo.tray(t1)!.ledIndex, 1);
    expect(() => repo.setLed(t1, 60), throwsA(isA<ValidationException>()));
  });

  test("đánh số LED tự động theo hàng zig-zag", () async {
    final ids = [
      await repo.addTray(storageId, a6.id, xMm: 0, yMm: 0),
      await repo.addTray(storageId, a6.id, xMm: 200, yMm: 0),
      await repo.addTray(storageId, a6.id, xMm: 0, yMm: 150),
      await repo.addTray(storageId, a6.id, xMm: 200, yMm: 150),
    ];
    expect(await repo.autoNumberLeds(storageId, LedOrder.snakeRows), 4);
    expect([for (final id in ids) repo.tray(id)!.ledIndex], [0, 1, 3, 2]);
  });

  test("cất linh kiện, lọc ngăn sai, xoá khay => chưa có chỗ", () async {
    final (_, variants) = await createComponent("Tụ 100nF");
    final v = variants[""]!;
    final tray = await repo.addTray(storageId, f0.id, xMm: 0, yMm: 0);
    await repo.place(v.id, tray, compartmentIndex: 2);
    expect(reload(v).placeLabel, "F0-01 / ngăn 3");
    expect(
      () => repo.place(v.id, tray, compartmentIndex: 3),
      throwsA(isA<ValidationException>()),
    );

    // Đổi sang loại ít ngăn hơn => dồn về ngăn cuối
    final t = repo.tray(tray)!..trayType.targetId = a6.id;
    await repo.updateTray(t);
    expect(reload(v).compartmentIndex, 0);

    await repo.deleteTrays([tray]);
    expect(reload(v).hasPlace, isFalse);
  });

  test("không xoá được loại khay đang dùng", () async {
    await repo.addTray(storageId, a6.id, xMm: 0, yMm: 0);
    expect(
      () => TrayTypeRepository().delete(a6.id),
      throwsA(isA<ValidationException>()),
    );
  });

  test("xoá kho rồi hoàn tác: khay, LED và chỗ cất quay lại", () async {
    final (_, variants) = await createComponent("Arduino Nano");
    final v = variants[""]!;
    final tray = await repo.addTray(storageId, a6.id, xMm: 10, yMm: 20);
    await repo.setLed(tray, 5);
    await repo.place(v.id, tray);

    final transfer = DataTransferService();
    final snapshot = transfer.snapshot(storageIds: [storageId]);
    await repo.delete(storageId);
    expect(db.get<StorageTray>().isEmpty(), isTrue);
    expect(reload(v).hasPlace, isFalse);

    transfer.restore(snapshot);
    final restored = db.get<StorageTray>().getAll().single;
    expect(restored.ledIndex, 5);
    expect(restored.xMm, 10);
    expect(restored.storage.target!.name, "Kho");
    expect(reload(v).tray.targetId, restored.id);
  });

  test("sao lưu rồi khôi phục giữ nguyên kho", () async {
    final (_, variants) = await createComponent(
      "Điện trở",
      attributes: [
        VariantAttribute("Giá trị", ["10k", "1k"]),
      ],
      variants: [
        {"Giá trị": "10k"},
        {"Giá trị": "1k"},
      ],
    );
    final tray = await repo.addTray(storageId, f0.id, xMm: 0, yMm: 0);
    await repo.setLed(tray, 2);
    await repo.place(variants["10k"]!.id, tray, compartmentIndex: 1);

    final transfer = DataTransferService();
    final data = transfer.exportAll();
    expect(data["version"], DataTransferService.version);
    transfer.replaceAll(data);

    final v = db.get<ComponentVariant>().getAll().firstWhere(
      (v) => v.selection["Giá trị"] == "10k",
    );
    expect(v.placeLabel, "F0-01 / ngăn 2");
    expect(v.tray.target!.ledIndex, 2);
    expect(v.tray.target!.storage.target!.powerSupply.target!.currentA, 2.4);
    expect(db.get<TrayType>().getAll().map((t) => t.name), contains("Khay A6"));
  });

  test(
    "tìm linh kiện: màu báo ngăn, nháy phân biệt linh kiện, báo thiếu",
    () async {
      final (_, a) = await createComponent("Module ESP32");
      final (_, b) = await createComponent("Tụ 10uF");
      final (_, c) = await createComponent("LED 5mm");
      final (_, d) = await createComponent("Không chỗ");
      final ta6 = await repo.addTray(storageId, a6.id, xMm: 0, yMm: 0);
      final tf0 = await repo.addTray(storageId, f0.id, xMm: 200, yMm: 0);
      final noLed = await repo.addTray(storageId, f0.id, xMm: 400, yMm: 0);
      await repo.setLed(ta6, 0);
      await repo.setLed(tf0, 1);
      await repo.place(a[""]!.id, ta6);
      await repo.place(b[""]!.id, tf0, compartmentIndex: 1);
      await repo.place(c[""]!.id, noLed);

      final result = LocatePlanner.plan([
        LocateTarget(reload(a[""]!), color: 0xFFFF0000),
        LocateTarget(reload(b[""]!)),
        LocateTarget(reload(c[""]!)),
        LocateTarget(reload(d[""]!)),
      ]);
      expect(result.misses.map((m) => m.reason), [
        "Khay F0-02 chưa gắn LED",
        "Chưa có chỗ cất",
      ]);
      final requests = result.requests.single.requests;
      final onA6 = requests.firstWhere((r) => r.ledIndex == 0);
      // Khay A6 chỉ cho xanh dương dù muốn đỏ
      expect(onA6.color, blue);
      expect(onA6.minBrightness, 120);
      expect(onA6.effect, LedEffect.solid);
      // Ngăn 2 của F0 = xanh lá thuần; linh kiện thứ 2 trong lần tìm => nháy chậm
      final onF0 = requests.firstWhere((r) => r.ledIndex == 1);
      expect(onF0.color, 0xFF00FF00);
      expect(onF0.effect, LedEffect.blinkSlow);

      // Tìm 1 linh kiện: sáng liên tục, màu theo ngăn
      await repo.place(b[""]!.id, tf0, compartmentIndex: 2);
      final single = LocatePlanner.plan([
        LocateTarget(reload(b[""]!)),
      ]).requests.single.requests.single;
      expect(single.color, 0xFF0000FF);
      expect(single.effect, LedEffect.solid);

      // Gộp hết vách còn 1 ngăn => màu mặc định của loại khay
      await repo.setRemovedDividers(tf0, 3);
      final merged = LocatePlanner.plan([
        LocateTarget(reload(b[""]!)),
      ]).requests.single.requests.single;
      expect(
        merged.color,
        reload(b[""]!).tray.target!.trayType.target!.defaultColor,
      );
    },
  );

  test(
    "màu báo ngăn: tự chọn được, khay màu cố định báo ngăn bằng nháy",
    () async {
      final free = TrayType(name: "Hộp 3 ngăn", compartmentCount: 3);
      expect(free.colorForCompartment(0, 3), 0xFFFF0000);
      expect(free.colorForCompartment(1, 3), 0xFF00FF00);
      expect(free.colorForCompartment(2, 3), 0xFF0000FF);
      expect(free.colorForCompartment(0, 1), free.defaultColor);
      free.setCompartmentColors([0xFFFFFF00, 0xFFFF00FF]);
      expect(free.compartmentColorList(), [0xFFFFFF00, 0xFFFF00FF]);
      expect(free.colorForCompartment(1, 2), 0xFFFF00FF);
      free.setCompartmentColors(const []);
      expect(free.compartmentColorsJson, "");

      // Khay chỉ xanh dương, 2 ngăn: màu không báo được ngăn => nháy 2 lần
      final blue2 = TrayType(
        name: "Khay xanh 2 ngăn",
        compartmentCount: 2,
        allowedColorsJson: "[$blue]",
        defaultColor: blue,
      );
      blue2.id = await TrayTypeRepository().add(blue2);
      final (_, part) = await createComponent("Điện trở 1k");
      final tray = await repo.addTray(storageId, blue2.id, xMm: 0, yMm: 0);
      await repo.setLed(tray, 0);
      await repo.place(part[""]!.id, tray, compartmentIndex: 1);
      final r = LocatePlanner.plan([
        LocateTarget(reload(part[""]!)),
      ]).requests.single.requests.single;
      expect(r.color, blue);
      expect(r.effect, LedEffect.count2);
    },
  );

  test(
    "gợi ý chỗ cất: module vào A6, tụ vào ngăn F0 còn trống; đọc câu trả lời AI",
    () async {
      final (_, module) = await createComponent("Module relay 1 kênh");
      final (_, tu1) = await createComponent("Tụ gốm 100nF");
      final (_, tu2) = await createComponent("Tụ gốm 10nF");
      final ta6 = await repo.addTray(storageId, a6.id, xMm: 0, yMm: 0);
      final tf0 = await repo.addTray(storageId, f0.id, xMm: 200, yMm: 0);
      await repo.setLed(ta6, 0);
      await repo.setLed(tf0, 1);
      await repo.place(tu1[""]!.id, tf0, compartmentIndex: 0);

      final assistant = PlaceAssistant(repo.traysOf(storageId));
      expect(assistant.rank(reload(module[""]!)).first.slot.tray.id, ta6);
      final forTu = assistant.rank(reload(tu2[""]!)).first.slot;
      expect(forTu.tray.id, tf0);
      expect(forTu.compartment, isNot(0));

      final candidates = assistant.rank(reload(tu2[""]!));
      final picked = assistant.parse(
        'Chọn: ```json\n{"slot": "$tf0:2", "reason": "cạnh tụ 100nF"}\n```',
        candidates,
        model: "test",
      );
      expect(picked.slot.label, "F0-01 / ngăn 3");
      expect(picked.reasons, ["cạnh tụ 100nF"]);
      expect(
        () => assistant.parse('{"slot": "999:0"}', candidates),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  group("Vách ngăn tháo được", () {
    test("chia ngăn từ mặt nạ vách", () {
      expect(Compartments.sizes(3, 0), [1, 1, 1]);
      expect(Compartments.sizes(3, 0x1), [2, 1]);
      expect(Compartments.sizes(3, 0x2), [1, 2]);
      expect(Compartments.sizes(3, 0x3), [3]);
      expect(Compartments.describe(3, 0x1), "To | nhỏ");
      expect(Compartments.describe(3, 0x2), "Nhỏ | to");
      expect(Compartments.allLayouts(3), [0, 1, 2, 3]);
      expect(Compartments.ofSlot(3, 0x1, 1), 0);
      expect(Compartments.ofSlot(3, 0x1, 2), 1);
      expect(Compartments.firstSlot(3, 0x2, 1), 1);
    });

    test("tháo / lắp vách: linh kiện dồn sang ngăn chứa khe cũ", () async {
      final (_, a) = await createComponent("Điện trở 1k");
      final (_, b) = await createComponent("Điện trở 10k");
      final (_, c) = await createComponent("Điện trở 100k");
      final tray = await repo.addTray(storageId, f0.id, xMm: 0, yMm: 0);
      await repo.place(a[""]!.id, tray, compartmentIndex: 0);
      await repo.place(b[""]!.id, tray, compartmentIndex: 1);
      await repo.place(c[""]!.id, tray, compartmentIndex: 2);

      // Tháo vách giữa ngăn 1 và 2 => ngăn to (khe 0–1) + ngăn nhỏ (khe 2)
      await repo.setRemovedDividers(tray, 0x1);
      expect([a, b, c].map((v) => reload(v[""]!).compartmentIndex), [0, 0, 1]);
      expect(reload(c[""]!).placeLabel, "F0-01 / ngăn 2 (nhỏ)");
      expect(repo.tray(tray)!.compartmentCount, 2);
      expect(
        () => repo.place(a[""]!.id, tray, compartmentIndex: 2),
        throwsA(isA<ValidationException>()),
      );

      // Lắp lại đủ vách: mỗi linh kiện về khe đầu của ngăn cũ
      await repo.setRemovedDividers(tray, 0);
      expect([a, b, c].map((v) => reload(v[""]!).compartmentIndex), [0, 0, 2]);

      // 1 ngăn
      await repo.setRemovedDividers(tray, 0x3);
      expect(reload(c[""]!).placeLabel, "F0-01");
      expect(
        () => repo.setRemovedDividers(tray, 0x4),
        throwsA(isA<ValidationException>()),
      );

      // Khay A6 không tháo được vách
      final ta6 = await repo.addTray(storageId, a6.id, xMm: 300, yMm: 0);
      expect(
        () => repo.setRemovedDividers(ta6, 0),
        throwsA(isA<ValidationException>()),
      );

      // Sao lưu giữ cách chia ngăn
      final transfer = DataTransferService();
      transfer.replaceAll(transfer.exportAll());
      final restored = db.get<StorageTray>().getAll().firstWhere(
        (t) => t.label == "F0-01",
      );
      expect(restored.removedDividers, 0x3);
      expect(restored.trayType.target!.removableDividers, isTrue);
    });
  });

  group("đánh số / dời LED, chuyển ngăn", () {
    late List<int> ids;
    setUp(() async {
      // lưới 5 cột x 3 hàng
      ids = [
        for (var r = 0; r < 3; r++)
          for (var c = 0; c < 5; c++)
            await repo.addTray(
              storageId,
              a6.id,
              xMm: c * 200.0,
              yMm: r * 150.0,
            ),
      ];
      final st = repo.get(storageId)!..ledCount = 60;
      await repo.update(st);
    });
    List<int> leds() => [for (final id in ids) repo.tray(id)!.ledIndex];

    test("numberLeds: góc dưới-phải zig-zag, bỏ LED khay xung đột", () async {
      await repo.setLed(ids[0], 2); // ngoài vùng chọn, nằm trong dải
      await repo.numberLeds(
        storageId,
        ids.sublist(5),
        0,
        LedOrder.snakeRows,
        corner: LedCorner.bottomRight,
      );
      expect(leds().sublist(10), [4, 3, 2, 1, 0]);
      expect(leds().sublist(5, 10), [5, 6, 7, 8, 9]);
      expect(leds()[0], -1); // bị bỏ LED vì nằm trong dải 0–9
    });

    test("numberLeds: xung đột ném lỗi khi không cho bỏ, vượt LED ném lỗi", () {
      return () async {
        await repo.setLed(ids[0], 1);
        await expectLater(
          repo.numberLeds(
            storageId,
            ids.sublist(10),
            0,
            LedOrder.rows,
            clearConflicts: false,
          ),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repo.numberLeds(storageId, ids.sublist(10), 57, LedOrder.rows),
          throwsA(isA<ValidationException>()),
        );
      }();
    });

    test("shiftLeds dương, âm, lỗi và restoreLeds", () async {
      await repo.numberLeds(storageId, ids.sublist(0, 4), 0, LedOrder.rows);
      final snap = repo.ledSnapshot(storageId);
      await repo.shiftLeds(storageId, 2, 3);
      expect(leds().sublist(0, 4), [0, 1, 5, 6]);
      await repo.shiftLeds(storageId, 5, -3);
      expect(leds().sublist(0, 4), [0, 1, 2, 3]);
      await expectLater(
        repo.shiftLeds(storageId, 2, -1),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repo.shiftLeds(storageId, 0, 59),
        throwsA(isA<ValidationException>()),
      );
      await repo.shiftLeds(storageId, 2, 5);
      await repo.restoreLeds(snap);
      expect(leds().sublist(0, 4), [0, 1, 2, 3]);
    });

    test("moveCompartment: gộp, đổi chỗ, chỉ số sai", () async {
      final f1 = await repo.addTray(storageId, f0.id, xMm: 0, yMm: 500);
      final f2 = await repo.addTray(storageId, f0.id, xMm: 200, yMm: 500);
      final (_, a) = await createComponent("Tụ A");
      final (_, b) = await createComponent("Tụ B");
      await repo.place(a[""]!.id, f1, compartmentIndex: 0);
      await repo.place(b[""]!.id, f2, compartmentIndex: 1);

      await repo.moveCompartment(f1, 0, f2, 1, swap: false);
      expect(reload(a[""]!).tray.targetId, f2);
      expect(reload(a[""]!).compartmentIndex, 1);
      expect(repo.contentsOf(f2)[1]!.length, 2);

      await repo.place(a[""]!.id, f1, compartmentIndex: 2);
      await repo.moveCompartment(f1, 2, f2, 1, swap: true);
      expect(reload(a[""]!).tray.targetId, f2);
      expect(reload(b[""]!).tray.targetId, f1);
      expect(reload(b[""]!).compartmentIndex, 2);

      await repo.moveCompartment(f1, 2, f1, 2, swap: false); // không làm gì
      expect(
        () => repo.moveCompartment(f1, 5, f2, 0, swap: false),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
