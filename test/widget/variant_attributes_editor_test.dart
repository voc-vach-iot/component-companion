import 'package:component_companion/model/variant.dart';
import 'package:component_companion/widget/component/variant_attributes_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<VariantAttribute> attributes;
  late AttributeRenames renames;

  Future<void> pump(WidgetTester tester, List<VariantAttribute> initial) async {
    attributes = initial;
    renames = AttributeRenames.none;
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VariantAttributesEditor(
              initial: initial,
              onChanged: (a, r) {
                attributes = a;
                renames = r;
              },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets("giá trị mới được chèn đúng thứ tự", (tester) async {
    await pump(tester, const [
      VariantAttribute("Điện dung", ["0.1uF", "1uF", "10uF"]),
    ]);
    await tester.enterText(find.byType(TextField).at(1), "0.22uF");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(attributes.single.values, ["0.1uF", "0.22uF", "1uF", "10uF"]);
  });

  testWidgets("sửa giá trị => báo đổi tên, giữ vị trí", (tester) async {
    await pump(tester, const [
      VariantAttribute("Điện dung", ["0.1u", "1uF"]),
    ]);
    await tester.tap(find.text("0.1u"));
    await tester.pumpAndSettle();
    expect(find.text("Sửa giá trị"), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      "0.1uF",
    );
    await tester.pump();
    await tester.tap(find.text("Lưu"));
    await tester.pumpAndSettle();
    expect(attributes.single.values, ["0.1uF", "1uF"]);
    expect(renames.values, {
      "Điện dung": {"0.1u": "0.1uF"},
    });
  });

  testWidgets("đổi thứ tự thuộc tính", (tester) async {
    await pump(tester, const [
      VariantAttribute("Điện áp", ["16V"]),
      VariantAttribute("Điện dung", ["1uF"]),
    ]);
    await tester.tap(find.byTooltip("Đưa thuộc tính lên").last);
    await tester.pump();
    expect(attributes.map((a) => a.name), ["Điện dung", "Điện áp"]);
  });
}
