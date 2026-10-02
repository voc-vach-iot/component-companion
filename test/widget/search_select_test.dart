import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Không đọc/ghi DB trong test.
class _MemorySearchOptions extends SearchOptionsNotifier {
  @override
  SearchOptions build() => const SearchOptions();

  @override
  void update(SearchOptions options) => state = options;
}

void main() {
  const items = ["Tụ hóa 470uF", "Tụ gốm 104", "Điện trở 10K", "ESP32"];

  Future<ValueNotifier<String?>> pump(WidgetTester tester) async {
    final selected = ValueNotifier<String?>(null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchOptionsProvider.overrideWith(_MemorySearchOptions.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: ValueListenableBuilder(
                valueListenable: selected,
                builder: (context, value, _) => AppSearchSelect<String>(
                  label: "Linh kiện",
                  items: items,
                  value: value,
                  noneLabel: "— Không chọn —",
                  labelOf: (s) => s,
                  onChanged: (v) => selected.value = v,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return selected;
  }

  testWidgets("gõ không dấu để lọc rồi chọn", (tester) async {
    final selected = await pump(tester);
    await tester.tap(find.text("— Không chọn —"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), "tu");
    await tester.pumpAndSettle();
    // Chỉ còn 2 tụ (highlight dùng Text.rich nên tìm theo nội dung)
    expect(find.textContaining("Tụ hóa", findRichText: true), findsOneWidget);
    expect(find.textContaining("Tụ gốm", findRichText: true), findsOneWidget);
    expect(find.textContaining("ESP32", findRichText: true), findsNothing);

    await tester.tap(find.textContaining("Tụ gốm", findRichText: true));
    await tester.pumpAndSettle();
    expect(selected.value, "Tụ gốm 104");
    expect(find.byType(TextField), findsNothing); // popup đã đóng
  });

  testWidgets("điều hướng bằng phím", (tester) async {
    final selected = await pump(tester);
    await tester.tap(find.text("— Không chọn —"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), "e");
    await tester.pumpAndSettle();
    // "e" khớp "ESP32" (vị trí 0) và "Điện trở" (vị trí 2) => xếp hạng ESP32 trước
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected.value, "Điện trở 10K");

    await tester.tap(find.text("Điện trở 10K"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "e");
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected.value, "ESP32");
  });
}
