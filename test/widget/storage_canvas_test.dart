import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/widget/storage/storage_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final type = TrayType(name: "T", widthMm: 100, depthMm: 50, heightMm: 40);
  StorageTray tray(int id, double x, double y) {
    final t = StorageTray(id: id, xMm: x, yMm: y, label: "T$id");
    t.trayType.target = type;
    return t;
  }

  final storage = Storage(name: "K", widthMm: 400, heightMm: 300, gridMm: 10);
  final trays = [tray(1, 20, 20), tray(2, 250, 20), tray(3, 20, 200)];

  Future<
    ({List<Set<int>> selects, List<Map<int, Offset>> moves, List<Offset> menus})
  >
  pump(WidgetTester tester) async {
    final selects = <Set<int>>[];
    final moves = <Map<int, Offset>>[];
    final menus = <Offset>[];
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorageCanvas(
            storage: storage,
            trays: trays,
            selected: const {},
            mode: CanvasMode.arrange,
            zoom: 1,
            session: null,
            onSelect: selects.add,
            onZoom: (_) {},
            onMove: moves.add,
            onWireTap: (_) {},
            onDropType: (_, _) {},
            onDropVariant: (_, _, _) {},
            onContextMenu: (t, c, p) => menus.add(p),
          ),
        ),
      ),
    );
    return (selects: selects, moves: moves, menus: menus);
  }

  testWidgets("kéo chuột trái trên nền chọn đúng khay giao khung", (
    tester,
  ) async {
    final r = await pump(tester);
    final box = tester.getTopLeft(find.byType(CustomPaint).first);
    final g = await tester.startGesture(
      box + const Offset(5, 5),
      kind: PointerDeviceKind.mouse,
    );
    await g.moveBy(const Offset(100, 100));
    await g.moveBy(const Offset(100, 100));
    await g.up();
    await tester.pump();
    expect(r.selects.last, {1});
    expect(r.moves, isEmpty);
  });

  testWidgets("chuột phải kéo không chọn hay di chuyển khay", (tester) async {
    final r = await pump(tester);
    final box = tester.getTopLeft(find.byType(CustomPaint).first);
    final g = await tester.startGesture(
      box + const Offset(30, 30),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await g.moveBy(const Offset(80, 80));
    await g.up();
    await tester.pump();
    expect(r.selects, isEmpty);
    expect(r.moves, isEmpty);
    expect(r.menus, isEmpty);
  });

  testWidgets("chuột phải bấm không kéo mở menu ngữ cảnh", (tester) async {
    final r = await pump(tester);
    final box = tester.getTopLeft(find.byType(CustomPaint).first);
    final g = await tester.startGesture(
      box + const Offset(30, 30),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await g.up();
    await tester.pump();
    expect(r.menus, hasLength(1));
  });
}
