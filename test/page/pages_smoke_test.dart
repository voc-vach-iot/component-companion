import 'dart:io';

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
import 'package:component_companion/widget/data/import_dialog.dart';
import 'package:component_companion/widget/project/project_stock_dialog.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/widget/project/bom_paste_dialog.dart';
import 'package:component_companion/widget/project/project_item_dialog.dart';
import 'package:flutter/material.dart';
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
    expect(
      find.textContaining("Chọn 1 trong 2 phương án", findRichText: true),
      findsOneWidget,
    );
    expect(find.text("Thêm nhóm lựa chọn"), findsWidgets);
    // Chung 2 x 95k + ESP32 1 x 95k
    expect(find.textContaining("285.000"), findsWidgets);
    await unmount(tester);
  });

  testWidgets("danh sách dự án", (tester) async {
    await pumpPage(tester, const ProjectPage());
    expect(find.text("Robot dò line"), findsOneWidget);
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
    expect(find.text("Tạo mới"), findsOneWidget);
    expect(find.textContaining("Shop A → Shop A (Shopee)"), findsOneWidget);
    expect(find.textContaining("Đang giao → đang về"), findsOneWidget);
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
}
