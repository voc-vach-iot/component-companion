import 'package:component_companion/widget/input/keyword_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets("KeywordInput chặn keyword trùng và keyword đã thuộc nơi khác", (
    tester,
  ) async {
    List<String>? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeywordInput(
            initialKeywords: const ["esp32"],
            onChanged: (value) => latest = value,
            validator: (keyword) => keyword == "servo"
                ? "'servo' đã thuộc danh mục 'Động cơ'"
                : null,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      "Servo, ESP32,  Blue   Pill",
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(latest, ["esp32", "blue pill"]);
    expect(find.text("blue pill"), findsOneWidget);
    expect(find.textContaining("đã thuộc danh mục 'Động cơ'"), findsOneWidget);
    expect(
      find.textContaining("'esp32' đã có trong danh sách"),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      "",
    );
  });
}
