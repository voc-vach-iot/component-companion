import 'dart:io';

import 'package:component_companion/data/power_supply_repository.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/data/tray_type_repository.dart';
import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/page/storage_page.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/widget/storage/place_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

/// Render trang Kho với DB thật để bắt lỗi layout / provider.
void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async {
    (db, dir) = await openTestDb();
    final types = TrayTypeRepository();
    final a6 = await types.add(
      TrayType(
        name: "Khay A6",
        widthMm: 200,
        depthMm: 150,
        heightMm: 120,
        stackGapMm: 30,
        allowedColorsJson: "[${0xFF0050FF}]",
        defaultColor: 0xFF0050FF,
      ),
    );
    final f0 = await types.add(
      TrayType(
        name: "Khay F0",
        widthMm: 140,
        depthMm: 93,
        heightMm: 34,
        compartmentCount: 3,
        removableDividers: true,
      ),
    );
    final supply = await PowerSupplyRepository().add(
      PowerSupply(name: "Adapter 5V 2.4A", currentA: 2.4),
    );
    final repo = StorageRepository();
    final storage = await repo.add(
      Storage(name: "Kho chính")..powerSupply.targetId = supply,
    );
    final t1 = await repo.addTray(storage, a6, xMm: 0, yMm: 0);
    final t2 = await repo.addTray(storage, f0, xMm: 200, yMm: 0);
    await repo.addTray(storage, f0, xMm: 200, yMm: 40);
    await repo.setLed(t1, 0);
    await repo.setLed(t2, 1);
    final (_, v) = await createComponent("Module ESP32-C3 SuperMini");
    await repo.place(v[""]!.id, t1);
    await createComponent("Tụ gốm 100nF");
  });
  tearDown(() => closeTestDb(db, dir));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      // Cho animation chuyển tab / mở dialog chạy xong
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1440, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: page)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }

  testWidgets("sơ đồ kho: khay, chưa có chỗ, sáng thử rồi tắt", (tester) async {
    await pumpPage(tester, const StoragePage());
    expect(find.text("A6-01"), findsWidgets);
    expect(find.text("F0-02"), findsOneWidget);
    expect(find.text("Chưa có chỗ (1)"), findsOneWidget);
    expect(find.text("Tụ gốm 100nF"), findsOneWidget);
    // Khay F0-02 chưa gắn LED => cảnh báo trong tổng quan kho
    expect(find.text("2 / 60"), findsOneWidget);

    await tester.tap(find.text("Sáng thử tất cả"));
    await settle(tester);
    expect(find.textContaining("Đang sáng 2 LED (giả lập)"), findsOneWidget);
    await tester.tap(find.text("Tắt LED"));
    await settle(tester);
    expect(find.textContaining("Đang sáng"), findsNothing);

    // Chọn khay => panel chi tiết
    await tester.tap(find.text("F0-01").first);
    await settle(tester);
    expect(find.text("Ngăn 3"), findsOneWidget);
    // Tháo vách: chọn "To | nhỏ" => còn 2 ngăn
    await tester.tap(find.text("To | nhỏ"));
    await settle(tester);
    expect(find.text("Ngăn 3"), findsNothing);
    expect(find.text("Ngăn 2"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("tab loại khay và nguồn", (tester) async {
    await pumpPage(tester, const StoragePage());
    await tester.tap(find.text("Loại khay"));
    await settle(tester);
    expect(find.text("Khay F0"), findsWidgets);
    expect(find.textContaining("chỉ 1 màu"), findsOneWidget);
    await tester.tap(find.text("Nguồn"));
    await settle(tester);
    expect(find.textContaining("1920 mA"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("chọn chỗ cất: gợi ý ngăn nhỏ cho tụ", (tester) async {
    final variant = db.get<Storage>().getAll().first.trays.first.variants.first;
    final tu = (await createComponent("Tụ hoá 10uF")).$2[""]!;
    await pumpPage(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => PlacePickerDialog.show(context, tu),
          child: const Text("mở"),
        ),
      ),
    );
    await tester.tap(find.text("mở"));
    await settle(tester);
    expect(find.text("Chỗ cất: Tụ hoá 10uF"), findsOneWidget);
    // Gợi ý đầu là 1 ngăn F0 trống
    expect(find.textContaining("F0-01 / ngăn"), findsWidgets);
    expect(variant.fullLabel, "Module ESP32-C3 SuperMini");
    await tester.tap(find.text("Cất vào đây"), warnIfMissed: false);
    await settle(tester);
    await unmount(tester);
  });
}
