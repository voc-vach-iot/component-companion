import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/widget/category/category_dialog.dart';
import 'package:component_companion/widget/component/component_dialog.dart';
import 'package:component_companion/widget/component_type/component_type_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="9"/></svg>';

Future<void> _pumpDialog(WidgetTester tester, Widget dialog) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showDialog(context: context, builder: (_) => dialog),
            child: const Text("open"),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text("open"));
  await tester.pumpAndSettle();
}

void main() {
  final categories = [
    Category(
      id: 1,
      name: "Linh kiện thụ động",
      colorValue: 0xFFFFD1DC,
      iconSvg: _svg,
      keywords: ["tụ hóa", "điện trở"],
    ),
  ];
  final type = ComponentType(
    id: 1,
    name: "Tụ hóa",
    defaultIconSvg: _svg,
    keywords: ["tụ hóa"],
  )..category.targetId = 1;

  testWidgets("CategoryDialog hiển thị", (tester) async {
    await _pumpDialog(
      tester,
      CategoryDialog(category: categories.first, onSave: (_) {}),
    );
    expect(find.text("Sửa danh mục"), findsOneWidget);
  });

  testWidgets("ComponentTypeDialog hiển thị", (tester) async {
    await _pumpDialog(
      tester,
      ComponentTypeDialog(type: type, categories: categories, onSave: (_) {}),
    );
    expect(find.text("Sửa loại linh kiện"), findsOneWidget);
  });

  testWidgets("ComponentDialog tự nhận diện danh mục + loại", (tester) async {
    await _pumpDialog(
      tester,
      ComponentDialog(categories: categories, types: [type], onSave: (_) {}),
    );
    expect(find.text("Thêm linh kiện mới"), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, "Tụ hóa 470uF 16V");
    await tester.pumpAndSettle();
    expect(find.text("Linh kiện thụ động"), findsOneWidget);
    expect(find.text("Tụ hóa"), findsOneWidget);
  });
}
