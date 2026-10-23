import 'package:component_companion/model/variant.dart';
import 'package:component_companion/widget/project/project_item_action.dart';
import 'package:component_companion/widget/component/variant_finder_dialog.dart';
import 'dart:io';

import 'package:component_companion/data/app_setting_repository.dart';
import 'package:component_companion/data/icon_repository.dart';
import 'package:component_companion/data/project_group_repository.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/page/icon_library_page.dart';
import 'package:component_companion/page/project_detail_page.dart';
import 'package:component_companion/page/project_page.dart';
import 'package:component_companion/page/shopping_list_page.dart';
import 'package:component_companion/page/component_page.dart';
import 'package:component_companion/page/stock_log_page.dart';
import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/service/project_stock.dart';
import 'package:component_companion/widget/ai/ai_catalog_dialog.dart';
import 'package:component_companion/widget/data/import_dialog.dart';
import 'package:component_companion/widget/component/component_option_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/widget/icon/icon_picker_dialog.dart';
import 'package:component_companion/widget/project/project_stock_dialog.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/widget/project/bom_paste_dialog.dart';
import 'package:component_companion/widget/project/project_item_dialog.dart';
import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/model/entities/combo_part.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

/// Render các trang với DB thật để bắt lỗi layout (tràn, thiếu provider...).
void main() {
  late ObjectboxService db;
  late Directory dir;
  late int projectId;

  setUp(() async {
    (db, dir) = await openTestDb();
    final (component, variants) = await createComponent("ESP32 DevKit");
    final variant = variants[""]!;
    final offer = await addOffer(
      component,
      [variant],
      name: "1 cái",
      units: 1,
      price: 95000,
      shop: "Shop A",
    );
    projectId = db.get<Project>().put(
      Project(name: "Robot dò line", description: "Xe 2 bánh"),
    );
    final groupId = await ProjectGroupRepository().add(
      ProjectGroup(name: "Vi điều khiển")..project.targetId = projectId,
      ["ESP32", "STM32 Blue Pill có tên rất dài để thử tràn chữ"],
    );
    final group = ProjectGroupRepository().get(groupId)!;
    db.get<ProjectItem>().putMany([
      ProjectItem(quantity: 2)
        ..component.targetId = component.id
        ..variant.targetId = variant.id
        ..componentOption.targetId = offer
        ..project.targetId = projectId,
      ProjectItem(quantity: 1)
        ..component.targetId = component.id
        ..variant.targetId = variant.id
        ..componentOption.targetId = offer
        ..projectOption.targetId = group.sortedOptions.first.id,
    ]);
    IconRepository().import([
      IconAsset(
        name: "Tụ điện",
        svg: '<svg viewBox="0 0 24 24"><path d="M2 12h20"/></svg>',
        pack: "Ký hiệu mạch",
      ),
    ]);
  });
  tearDown(() => closeTestDb(db, dir));

  /// Gỡ cây widget (huỷ stream ObjectBox) trước khi đóng DB.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: page)),
      ),
    );
    // Stream ObjectBox phát trên luồng thật => chờ ngoài fake async
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  testWidgets("chi tiết dự án: chung + nhóm lựa chọn", (tester) async {
    await pumpPage(tester, ProjectDetailPage(projectId: projectId));
    expect(
      find.textContaining("Luôn có trong mọi cấu hình", findRichText: true),
      findsOneWidget,
    );
    expect(find.text("Cấu hình đang dùng"), findsOneWidget);
    // Nhóm lựa chọn nằm ở tab riêng
    expect(
      find.textContaining("Chọn 1 trong 2 phương án", findRichText: true),
      findsNothing,
    );
    await tester.tap(find.widgetWithText(ListTile, "Vi điều khiển"));
    await tester.pump();
    expect(
      find.textContaining("Chọn 1 trong 2 phương án", findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining("Luôn có trong mọi cấu hình", findRichText: true),
      findsNothing,
    );
    expect(find.text("Thêm nhóm lựa chọn"), findsWidgets);
    // Chung 2 x 95k + ESP32 1 x 95k
    expect(find.textContaining("285.000"), findsWidgets);
    await unmount(tester);
  });

  testWidgets("danh sách dự án", (tester) async {
    await pumpPage(tester, const ProjectPage());
    // Mặc định chỉ hiện dự án đang thực hiện; dự án mẫu đang lập kế hoạch
    expect(find.text("Robot dò line"), findsNothing);
    expect(find.textContaining("1 dự án ở trạng thái khác"), findsOneWidget);
    await tester.tap(find.textContaining("Lập kế hoạch (1)"));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text("Robot dò line"), findsOneWidget);
    // Lựa chọn lọc được nhớ
    expect(
      AppSettingRepository().get(ProjectPage.statusFilterKey),
      "planning,inProgress",
    );
    expect(
      find.textContaining("Vi điều khiển: ", findRichText: true),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets("cần mua: chọn phương án theo nhóm", (tester) async {
    await pumpPage(tester, ShoppingListPage(initialProjectId: projectId));
    expect(find.text("Vi điều khiển"), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets("thư viện icon", (tester) async {
    await pumpPage(tester, const IconLibraryPage());
    expect(find.text("Tụ điện"), findsOneWidget);
    expect(find.textContaining("Ký hiệu mạch"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("dialog linh kiện dự án: có nút tạo nhanh", (tester) async {
    final item = db.get<ProjectItem>().getAll().firstWhere(
      (i) => i.project.targetId == projectId,
    );
    final components = db.get<Component>().getAll();
    await pumpPage(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => ProjectItemDialog(
              projectItem: item,
              availableComponents: components,
              onSave: (_) {},
            ),
          ),
          child: const Text("open"),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
    expect(find.text("Sửa linh kiện"), findsOneWidget);
    expect(find.text("Tuỳ chọn mua mới"), findsOneWidget);
    expect(find.textContaining("Thành tiền: 190.000"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("dán BOM: khớp linh kiện có sẵn", (tester) async {
    final components = db.get<Component>().getAll();
    final project = db.get<Project>().get(projectId)!;
    await pumpPage(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => BomPasteDialog(
              project: project,
              availableComponents: components,
            ),
          ),
          child: const Text("open"),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      "3x ESP32 DevKit\nĐộng cơ bước x2",
    );
    await tester.tap(find.text("Phân tích"));
    await tester.pumpAndSettle();
    expect(find.text("Thêm 1 linh kiện"), findsOneWidget);
    expect(find.textContaining("1 chưa khớp"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("chi tiết dự án ở cửa sổ hẹp không tràn", (tester) async {
    await pumpPage(
      tester,
      ProjectDetailPage(projectId: projectId),
      size: const Size(900, 800),
    );
    expect(find.text("Dán BOM"), findsWidgets);
    await unmount(tester);

    // Rất hẹp => tab dọc thành hàng chip ngang
    await pumpPage(
      tester,
      ProjectDetailPage(projectId: projectId),
      size: const Size(700, 800),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, "Vi điều khiển"));
    await tester.pump();
    expect(
      find.textContaining("Chọn 1 trong 2 phương án", findRichText: true),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets("cần mua: đang về + cảnh báo giá tăng", (tester) async {
    final variant = db.get<ComponentVariant>().getAll().single;
    await VariantRepository().addIncoming({variant.id: 1});
    final option = db.get<ComponentOption>().getAll().single;
    db.get<PriceRecord>().put(
      PriceRecord(
        pricePerPack: 80000,
        unitsPerPack: 1,
        recordedAt: DateTime(2026, 1, 1),
      )..option.targetId = option.id,
    );
    await pumpPage(tester, ShoppingListPage(initialProjectId: projectId));
    expect(find.text("Đang về (1)"), findsOneWidget);
    expect(find.textContaining("đang về 1"), findsOneWidget);
    expect(find.textContaining("↑19% so với giá thấp nhất"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("linh kiện: nút Shopee + lọc chưa có tùy chọn mua", (
    tester,
  ) async {
    await createComponent("Tụ hóa chưa có giá");
    await pumpPage(tester, const ComponentPage());
    expect(find.text("Thêm từ Shopee"), findsOneWidget);
    expect(find.text("Chưa có tùy chọn mua"), findsWidgets);
    await tester.tap(find.widgetWithText(FilterChip, "Chưa có tùy chọn mua"));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text("1 linh kiện"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("linh kiện: Ctrl+V = thêm từ Shopee (ngoài ô nhập)", (
    tester,
  ) async {
    // Clipboard rỗng => hiện hướng dẫn bookmarklet
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    await pumpPage(tester, const ComponentPage());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text("Thêm linh kiện từ Shopee"), findsOneWidget);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await unmount(tester);
  });

  testWidgets("nhật ký kho", (tester) async {
    final variant = db.get<ComponentVariant>().getAll().single;
    await VariantRepository().adjustStock(variant.id, 5);
    await pumpPage(tester, const StockLogPage());
    expect(find.text("ESP32 DevKit"), findsOneWidget);
    expect(find.text("+5"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("xem trước nhập: khớp sẵn / tạo mới / đổi tên shop", (
    tester,
  ) async {
    final service = ImportService();
    final plans = service.plan(
      ImportService.parse(
        "Tên linh kiện,Giá gói,Shop,Số lượng mua,Trạng thái,Nguồn\n"
        "Board ESP32 DevKit V1,90000,Shop A,1,Đang giao,Shopee\n"
        "Cảm biến DS18B20,30000,Shop B,1,,",
      ),
    );
    await pumpPage(
      tester,
      ImportDialog(
        fileName: "Shopee",
        plans: plans,
        categories: db.get<Category>().getAll(),
        types: db.get<ComponentType>().getAll(),
        components: db.get<Component>().getAll(),
        shopHints: service.shopHints,
        onImport: (_, _, _) {},
      ),
    );
    expect(find.text("Khớp sẵn?"), findsOneWidget);
    expect(find.textContaining("Shop A → Shop A (Shopee)"), findsOneWidget);
    expect(find.textContaining("Đang giao → đang về"), findsOneWidget);

    // Dòng khớp đoán: nút "Tạo mới" ngay trên dòng, rồi quay lại gợi ý
    await tester.tap(find.widgetWithText(TextButton, "Tạo mới"));
    await tester.pump();
    expect(plans.first.existing, isNull);
    expect(find.text("Khớp sẵn?"), findsNothing);
    expect(find.text("Dùng: ESP32 DevKit"), findsOneWidget);
    await tester.tap(find.text("Dùng: ESP32 DevKit"));
    await tester.pump();
    expect(plans.first.existing?.name, "ESP32 DevKit");

    // Bỏ hàng loạt các khớp đoán
    await tester.tap(find.text("Bỏ 1 khớp đoán"));
    await tester.pump();
    expect(plans.first.existing, isNull);
    await unmount(tester);
  });

  testWidgets("xem trước nhập: tách combo cho dòng", (tester) async {
    final plans = ImportService().plan(
      ImportService.parse(
        "Tên linh kiện,Phân loại,Giá gói,Shop,Số lượng mua\n"
        "Combo cảm biến DS18B20 + ESP32,Bộ,120000,Shop A,1",
      ),
    );
    await pumpPage(
      tester,
      ImportDialog(
        fileName: "Shopee",
        plans: plans,
        categories: db.get<Category>().getAll(),
        types: db.get<ComponentType>().getAll(),
        components: db.get<Component>().getAll(),
        onImport: (_, _, _) {},
      ),
    );
    await tester.tap(find.text("Có vẻ là combo — tách thành phần"));
    await tester.pumpAndSettle();
    expect(find.textContaining("Linh kiện của dòng:"), findsOneWidget);

    await tester.tap(find.text("Chọn hoặc gõ tên để tạo linh kiện"));
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining("ESP32 DevKit", findRichText: true).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Lưu combo"));
    await tester.pumpAndSettle();

    expect(plans.single.isCombo, isTrue);
    expect(find.textContaining("+ 1 × ESP32 DevKit"), findsOneWidget);
    expect(find.textContaining("120.000"), findsWidgets);
    await unmount(tester);
  });

  testWidgets("xem trước nhập: combo dùng biến thể mới của linh kiện mới", (
    tester,
  ) async {
    final plans = ImportService().plan(
      ImportService.parse(
        "Tên linh kiện,Phân loại,Số cái/gói,Giá gói,Shop,Số lượng mua\n"
        "Jack XT60 đực cái,10 cặp,10,59000,Shop A,1",
      ),
    );
    plans.single.createNew();
    await pumpPage(
      tester,
      ImportDialog(
        fileName: "Shopee",
        plans: plans,
        categories: db.get<Category>().getAll(),
        types: db.get<ComponentType>().getAll(),
        components: db.get<Component>().getAll(),
        onImport: (_, _, _) {},
      ),
    );
    await tester.tap(find.text("Có vẻ là combo — tách thành phần"));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip("Biến thể mới của linh kiện dòng này (VD đầu cái)"),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, "Thuộc tính mới"),
      "Đầu",
    );
    await tester.enterText(find.widgetWithText(TextField, "Giá trị"), "Cái");
    await tester.pump();
    await tester.tap(find.text("Dùng biến thể này"));
    await tester.pumpAndSettle();
    expect(find.text("Jack XT60 đực cái · Mới: Cái"), findsWidgets);
    await tester.tap(find.text("Lưu combo"));
    await tester.pumpAndSettle();

    final extra = plans.single.comboExtras.single;
    expect(extra.isDraft, isTrue);
    expect(extra.selection, {"Đầu": "Cái"});
    // Thuộc tính mới hiện ở dòng => điền biến thể cho chính dòng (đầu đực)
    expect(find.textContaining("Chưa đủ thuộc tính"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("hỏi trừ kho khi dự án hoàn thành", (tester) async {
    final variant = db.get<ComponentVariant>().getAll().single..stock = 1;
    db.get<ComponentVariant>().put(variant);
    final project = db.get<Project>().get(projectId)!;
    await pumpPage(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => ProjectStockDialog.askConsume(context, project),
          child: const Text("mở"),
        ),
      ),
    );
    await tester.tap(find.text("mở"));
    await tester.pumpAndSettle();
    // Chung 2 + phương án đang chọn 1 = 3, kho 1 => thiếu 2
    expect(find.textContaining("kho 1 → 0 (thiếu 2)"), findsOneWidget);
    await tester.tap(find.text("Trừ kho 1 dòng"));
    await tester.pumpAndSettle();
    expect(db.get<ComponentVariant>().get(variant.id)!.stock, 0);
    expect(ProjectStockService().consumed(project).single.quantity, 1);
    await unmount(tester);
  });

  testWidgets(
    "xem trước nhập: tạo linh kiện + biến thể 1 lần cho cả sản phẩm",
    (tester) async {
      const name = "Thẻ nhớ MicroSD Kingston Class 10";
      final service = ImportService();
      final plans = service.plan(
        ImportService.parse(
          "Tên linh kiện,Phân loại,Giá gói,Shop\n"
          "$name,16GB,50000,Shop A\n"
          "$name,32GB,70000,Shop A\n"
          "$name,64GB,90000,Shop A",
        ),
      );
      // Không có linh kiện giống => cả 3 dòng tạo mới
      expect(plans.every((p) => p.existing == null), isTrue);
      await pumpPage(
        tester,
        ImportDialog(
          fileName: "Shopee",
          plans: plans,
          categories: db.get<Category>().getAll(),
          types: db.get<ComponentType>().getAll(),
          components: db.get<Component>().getAll(),
          onImport: (_, _, _) {},
        ),
      );
      expect(
        find.text("Không có biến thể — bấm + để thêm thuộc tính"),
        findsNWidgets(3),
      );

      // Dòng đầu: + => thuộc tính mới "Dung lượng", giá trị gợi ý từ Phân loại
      await tester.tap(find.byTooltip("Thêm thuộc tính / biến thể").first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, "Thuộc tính mới"),
        "Dung lượng",
      );
      await tester.pump();
      expect(find.widgetWithText(TextField, "16GB"), findsOneWidget);
      await tester.tap(find.text("Dùng biến thể này"));
      await tester.pumpAndSettle();

      expect(
        find.text("Đã điền biến thể cho 2 dòng khác cùng linh kiện"),
        findsOneWidget,
      );
      expect(plans.map((p) => p.attributes["Dung lượng"]), [
        "16GB",
        "32GB",
        "64GB",
      ]);
      expect(find.text("Mới: 32GB"), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets("nhờ AI: chưa có API key => sao chép prompt, dán câu trả lời", (
    tester,
  ) async {
    ({int categoryId, int typeId})? result;
    await pumpPage(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await AiCatalogDialog.show(
            context,
            name: "Thẻ nhớ MicroSD 32GB",
            categories: db.get<Category>().getAll(),
            types: db.get<ComponentType>().getAll(),
          ),
          child: const Text("mở"),
        ),
      ),
    );
    await tester.tap(find.text("mở"));
    await tester.pumpAndSettle();
    expect(find.textContaining("Chưa nhập API key"), findsOneWidget);
    expect(find.text("Sao chép prompt"), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).last,
      '{"category": {"existing": null, "new": {"name": "Lưu trữ", '
      '"color": "teal", "keywords": ["thẻ nhớ"], '
      '"iconSvg": "<svg viewBox=\\"0 0 24 24\\"><rect x=\\"5\\" y=\\"3\\" width=\\"14\\" height=\\"18\\"/></svg>"}}, '
      '"type": {"existing": null, "new": {"name": "Thẻ nhớ", '
      '"keywords": ["microsd"], "attributes": ["Dung lượng"]}}, '
      '"note": "Thẻ nhớ là thiết bị lưu trữ"}',
    );
    await tester.tap(find.text("Đọc câu trả lời"));
    await tester.pumpAndSettle();
    expect(find.text("DANH MỤC MỚI"), findsOneWidget);
    expect(find.text("LOẠI MỚI"), findsOneWidget);
    expect(find.text("Thuộc tính gợi ý: Dung lượng"), findsOneWidget);

    await tester.tap(find.text("Áp dụng"));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(db.get<Category>().get(result!.categoryId)!.name, "Lưu trữ");
    expect(db.get<ComponentType>().get(result!.typeId)!.name, "Thẻ nhớ");
    await unmount(tester);
  });

  testWidgets(
    "chọn icon: không thấy thì thêm mới / nhờ AI vẽ ngay trong dialog",
    (tester) async {
      await pumpPage(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showIconPicker(context, initialQuery: "thẻ nhớ microsd"),
            child: const Text("mở"),
          ),
        ),
      );
      await tester.tap(find.text("mở"));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(find.textContaining("Không có icon"), findsOneWidget);
      expect(find.text("Thêm icon (dán SVG)"), findsOneWidget);
      expect(find.text("Nhờ AI vẽ"), findsOneWidget);
      await tester.tap(find.text("Nhờ AI vẽ"));
      await tester.pumpAndSettle();
      // Chưa có API key => hỏi tay
      expect(find.text("Sao chép prompt"), findsOneWidget);
      // Ô "Vẽ icon cho" điền sẵn từ khoá đang tìm (cùng ô tìm của dialog chọn)
      expect(
        find.widgetWithText(TextField, "thẻ nhớ microsd"),
        findsNWidgets(2),
      );
      await unmount(tester);
    },
  );

  testWidgets("thẻ dự án: nhãn đã trừ kho", (tester) async {
    final project = db.get<Project>().get(projectId)!;
    final service = ProjectStockService();
    service.markConsumed(project, service.remaining(project));
    await pumpPage(tester, ProjectDetailPage(projectId: projectId));
    expect(find.text("Đã trừ kho"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("tuỳ chọn mua dạng combo: chọn thành phần của linh kiện khác", (
    tester,
  ) async {
    final (lcd, lv) = await createComponent("LCD1602");
    final (i2c, iv) = await createComponent("Module PCF8574");
    await addOffer(lcd, [lv[""]!], name: "1 cái", units: 1, price: 40000);
    await addOffer(i2c, [iv[""]!], name: "1 cái", units: 1, price: 20000);
    ComponentOption? saved;
    await pumpPage(
      tester,
      ComponentOptionDialog(
        component: db.get<Component>().get(lcd.id)!,
        shops: const [],
        onCreateShop: (_) async => null,
        allVariants: () => db.get<ComponentVariant>().getAll(),
        onSave: (o) async {
          saved = o;
          return false;
        },
      ),
    );
    await tester.tap(find.text("Combo / bộ (1 gói gồm nhiều linh kiện)"));
    await tester.pump();
    expect(find.text("Trong 1 combo có (1 loại)"), findsOneWidget);

    await tester.tap(find.text("Thêm linh kiện vào combo"));
    await tester.pump();
    expect(find.text("Trong 1 combo có (2 loại)"), findsOneWidget);
    // Thành phần 2 mặc định là biến thể đầu tiên chưa có => chọn PCF8574
    await tester.tap(find.text("ESP32 DevKit"));
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining("Module PCF8574", findRichText: true).last,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(AppTextField, "Giá cả combo (₫)"),
      "54000",
    );
    await tester.pump();
    expect(find.textContaining("LCD1602 ≈ 36.000"), findsOneWidget);
    expect(find.textContaining("Module PCF8574 ≈ 18.000"), findsOneWidget);

    await tester.tap(find.text("Thêm mới"));
    await tester.pump();
    expect(saved, isNotNull);
    expect(saved!.draftParts!.map((p) => p.variant.targetId), [
      lv[""]!.id,
      iv[""]!.id,
    ]);
    expect(saved!.name, "Combo");
    await unmount(tester);
  });

  testWidgets(
    "thêm linh kiện dự án theo combo: tính theo cái, không theo combo",
    (tester) async {
      final (screw, sv) = await createComponent("Vít M3x10");
      final (nut, nv) = await createComponent("Ốc M3");
      await ComponentOptionRepository().add(
        ComponentOption(name: "Vít kèm ốc", pricePerPack: 12000)
          ..component.targetId = screw.id
          ..draftParts = [
            ComboPart(quantity: 10)..variant.targetId = sv[""]!.id,
            ComboPart(quantity: 10)..variant.targetId = nv[""]!.id,
          ],
      );
      List<ProjectItem>? saved;
      await pumpPage(
        tester,
        ProjectItemDialog(
          project: db.get<Project>().get(projectId),
          availableComponents: db.get<Component>().getAll(),
          onSave: (_) {},
          onSaveCombo: (items) async => saved = items,
        ),
      );
      await tester.tap(find.text("Theo combo (1)"));
      await tester.pumpAndSettle();
      // Combo 10 vít + 10 ốc => 1 bộ = 1 vít + 1 ốc
      expect(
        find.textContaining("1 bộ = 1 Vít M3x10 + 1 Ốc M3"),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, "Số bộ cần dùng"),
        "4",
      );
      await tester.pump();
      expect(find.widgetWithText(TextFormField, "4"), findsNWidgets(2));
      expect(find.textContaining("Cần mua 1 combo = 12.000"), findsOneWidget);

      // Cần nhiều ốc hơn vít
      await tester.enterText(find.widgetWithText(TextFormField, "4").last, "6");
      await tester.pump();
      await tester.tap(find.text("Thêm 2 linh kiện"));
      await tester.pumpAndSettle();
      expect(saved, hasLength(2));
      final byVariant = {
        for (final i in saved!) i.variant.targetId: i.quantity,
      };
      expect(byVariant, {sv[""]!.id: 4, nv[""]!.id: 6});
      final comboId = db
          .get<ComponentOption>()
          .getAll()
          .singleWhere((o) => o.isCombo)
          .id;
      expect(
        saved!.every((i) => i.componentOption.targetId == comboId),
        isTrue,
      );
      await unmount(tester);
    },
  );

  testWidgets("thêm linh kiện trùng: báo nơi trùng, gộp số lượng", (
    tester,
  ) async {
    final variant = db.get<ComponentVariant>().getAll().single;
    final base = db.get<ProjectItem>().getAll().firstWhere(
      (i) => i.projectOption.targetId == 0,
    );
    await pumpPage(
      tester,
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => ProjectItemAction.addItems(context, ref, [
            ProjectItem(quantity: 3)
              ..component.targetId = variant.component.targetId
              ..variant.targetId = variant.id
              ..project.targetId = projectId,
          ]),
          child: const Text("Thêm"),
        ),
      ),
    );
    await tester.tap(find.text("Thêm"));
    await tester.pumpAndSettle();
    expect(find.text("Linh kiện đã có trong dự án"), findsOneWidget);
    expect(
      find.text("Gộp vào Linh kiện chung: đang 2 cái → 5 cái"),
      findsOneWidget,
    );
    expect(
      find.textContaining("Gộp vào Vi điều khiển › ESP32"),
      findsOneWidget,
    );
    expect(find.text("Huỷ thêm"), findsOneWidget);
    await tester.tap(find.text("Gộp 1"));
    await tester.pumpAndSettle();
    expect(db.get<ProjectItem>().get(base.id)!.quantity, 5);
    expect(db.get<ProjectItem>().count(), 2);
    await unmount(tester);
  });

  testWidgets("lọc biến thể theo khoảng thông số", (tester) async {
    await createComponent(
      "Pin Li-ion",
      attributes: [
        VariantAttribute("Dung lượng", ["2000mAh", "3500mAh"]),
      ],
      variants: [
        {"Dung lượng": "2000mAh"},
        {"Dung lượng": "3500mAh"},
      ],
    );
    await pumpPage(tester, const VariantFinderDialog());
    expect(find.text("3 biến thể"), findsOneWidget);
    await tester.tap(find.text("Thêm điều kiện"));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining("Dung lượng  ·  khoảng số"));
    await tester.pumpAndSettle();
    expect(find.text("2 biến thể"), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, "Từ"), "3Ah");
    await tester.pumpAndSettle();
    expect(find.text("1 biến thể"), findsOneWidget);
    expect(find.text("3500mAh"), findsWidgets);
    await unmount(tester);
  });

  testWidgets("trang dự án: báo dòng trùng, gộp được", (tester) async {
    final base = db.get<ProjectItem>().getAll().firstWhere(
      (i) => i.projectOption.targetId == 0,
    );
    db.get<ProjectItem>().put(
      ProjectItem(quantity: 4)
        ..component.targetId = base.component.targetId
        ..variant.targetId = base.variant.targetId
        ..componentOption.targetId = base.componentOption.targetId
        ..project.targetId = projectId,
    );
    await pumpPage(tester, ProjectDetailPage(projectId: projectId));
    expect(find.textContaining("1 linh kiện bị thêm trùng"), findsOneWidget);
    await tester.tap(find.text("Xem & gộp"));
    await tester.pumpAndSettle();
    expect(find.textContaining("2 + 4 = 6 cái"), findsOneWidget);
    await tester.tap(find.text("Gộp 1 nhóm"));
    await tester.pumpAndSettle();
    expect(db.get<ProjectItem>().get(base.id)!.quantity, 6);
    await unmount(tester);
  });

  testWidgets("bấm Lưu khi thêm linh kiện trùng => hiện dialog báo trùng", (
    tester,
  ) async {
    await pumpPage(
      tester,
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => ProjectItemAction.showAdd(
            context,
            ref,
            project: db.get<Project>().get(projectId),
          ),
          child: const Text("Mở"),
        ),
      ),
    );
    await tester.tap(find.text("Mở"));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Chọn linh kiện..."));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining("ESP32 DevKit").last);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Lưu"));
    await tester.pumpAndSettle();
    expect(find.text("Linh kiện đã có trong dự án"), findsOneWidget);
    await tester.tap(find.text("Huỷ thêm"));
    await tester.pumpAndSettle();
    expect(find.text("Linh kiện đã có trong dự án"), findsNothing);
    expect(db.get<ProjectItem>().count(), 2);
    await unmount(tester);
  });
}
