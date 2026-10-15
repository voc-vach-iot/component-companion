import 'dart:convert';
import 'dart:io';

import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/project_stock.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/service/stock_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  ComponentVariant reload(ComponentVariant v) =>
      db.get<ComponentVariant>().get(v.id)!;

  List<StockLog> logsOf(ComponentVariant v) =>
      StockLedger().history(variantId: v.id);

  group("nhật ký kho", () {
    test("sửa tay / cộng trừ / hoàn tác đều ghi nhật ký", () async {
      final (_, variants) = await createComponent("Trở 10K");
      final v = variants[""]!;
      final repo = VariantRepository();

      await repo.update(reload(v)..stock = 5);
      await repo.adjustStock(v.id, 3, reason: StockReason.stockIn);
      await repo.adjustStock(v.id, -10);
      await repo.restoreStocks({v.id: 8});

      expect(reload(v).stock, 8);
      final logs = logsOf(v).reversed.toList(); // cũ trước
      expect(logs.map((l) => (l.before, l.after, l.stockReason)), [
        (null, 5, StockReason.manual),
        (5, 8, StockReason.stockIn),
        (8, 0, StockReason.manual), // không xuống dưới 0
        (0, 8, StockReason.undo),
      ]);
      expect(logs.first.label, "Trở 10K");

      // Không đổi => không ghi
      await repo.update(reload(v));
      expect(logsOf(v), hasLength(4));
    });

    test("sửa biến thể không làm mất số đang về", () async {
      final (_, variants) = await createComponent("Trở 10K");
      final v = variants[""]!;
      final repo = VariantRepository();
      await repo.addIncoming({v.id: 20});
      // Dialog sửa tạo object mới không có incoming
      await repo.update(
        ComponentVariant(id: v.id, stock: 1)
          ..component.targetId = v.component.targetId,
      );
      expect(reload(v).incoming, 20);
    });

    test("gộp biến thể: nhật ký chuyển sang biến thể giữ lại", () async {
      final (component, variants) = await createComponent(
        "Còi",
        attributes: const [
          VariantAttribute("Điện áp", ["5V", "12V"]),
        ],
        variants: const [
          {"Điện áp": "5V"},
          {"Điện áp": "12V"},
        ],
      );
      final repo = VariantRepository();
      await repo.adjustStock(variants["5V"]!.id, 2);
      await repo.adjustStock(variants["12V"]!.id, 3);
      // Bỏ giá trị 12V => 2 biến thể gộp thành 1
      await ComponentRepository().update(
        db.get<Component>().get(component.id)!
          ..attributes = const [
            VariantAttribute("Điện áp", ["5V"]),
          ],
      );
      final keeper = db.get<Component>().get(component.id)!.variants.single;
      expect(keeper.stock, 5);
      final logs = logsOf(keeper);
      expect(logs, hasLength(3));
      expect(logs.first.stockReason, StockReason.merge);
    });
  });

  group("đang về", () {
    test("đã đặt => trừ khỏi số cần mua; đã nhận => vào kho", () async {
      final (component, variants) = await createComponent("Trở 10K");
      final v = variants[""]!;
      await addOffer(component, [v], name: "1 cái", units: 1, price: 100);
      final projectId = db.get<Project>().put(Project(name: "Robot"));
      db.get<ProjectItem>().put(
        ProjectItem(quantity: 10)
          ..component.targetId = component.id
          ..variant.targetId = v.id
          ..project.targetId = projectId,
      );
      List<ShoppingLine> lines() => ShoppingList.build(
        db.get<Project>().get(projectId)!.configurationEntries,
      );
      expect(lines().single.shortage, 10);

      final repo = VariantRepository();
      final previous = await repo.addIncoming({v.id: 6});
      expect(previous, {v.id: 0});
      expect(lines().single.shortage, 4);
      expect(lines().single.incoming, 6);

      final undo = await repo.receive([v.id]);
      expect(reload(v).incoming, 0);
      expect(reload(v).stock, 6);
      expect(logsOf(v).first.stockReason, StockReason.received);
      expect(lines().single.shortage, 4);

      // Hoàn tác nhận hàng
      await repo.restoreStocks(undo.stocks);
      await repo.restoreIncoming(undo.incoming);
      expect(reload(v).stock, isNull);
      expect(reload(v).incoming, 6);
    });
  });

  group("trừ kho khi dự án hoàn thành", () {
    late ComponentVariant tracked;
    late ComponentVariant untracked;
    late Project project;

    setUp(() async {
      final (a, va) = await createComponent("Trở 10K");
      final (b, vb) = await createComponent("ESP32");
      tracked = va[""]!..stock = 5;
      untracked = vb[""]!;
      db.get<ComponentVariant>().put(tracked);
      final id = db.get<Project>().put(
        Project(name: "Robot", status: ProjectStatus.completed.name),
      );
      for (final (component, variant, qty) in [
        (a, tracked, 3),
        (a, tracked, 4), // 2 dòng cùng biến thể => gộp
        (b, untracked, 1),
      ]) {
        db.get<ProjectItem>().put(
          ProjectItem(quantity: qty)
            ..component.targetId = component.id
            ..variant.targetId = variant.id
            ..project.targetId = id,
        );
      }
      project = db.get<Project>().get(id)!;
    });

    test("gộp theo biến thể, báo thiếu, bỏ qua biến thể không theo dõi", () {
      final usage = ProjectStockService().usage(project);
      expect(usage, hasLength(2));
      final line = usage.firstWhere((l) => l.variant.id == tracked.id);
      expect(line.quantity, 7);
      expect(line.enough, isFalse);
      expect(line.after, 0);
      expect(usage.firstWhere((l) => !l.tracked).variant.id, untracked.id);
    });

    test("trừ => số đã trừ; cộng lại; hoàn tác", () {
      final service = ProjectStockService();
      final logs = service.consume(project, service.usage(project));
      expect(logs, hasLength(1)); // biến thể không theo dõi bị bỏ qua
      expect(reload(tracked).stock, 0);
      expect(reload(untracked).stock, isNull);

      // Chỉ trừ được 5 (kho về 0) => cộng lại đúng 5
      final consumed = service.consumed(project);
      expect(consumed.single.quantity, 5);

      final back = service.giveBack(project, consumed);
      expect(reload(tracked).stock, 5);
      expect(service.consumed(project), isEmpty);

      // Hoàn tác cộng lại => lại đang trừ 5
      service.revert(project, back);
      expect(reload(tracked).stock, 0);
      expect(service.consumed(project).single.quantity, 5);

      // Hoàn tác lần trừ đầu
      service.revert(project, logs);
      expect(reload(tracked).stock, 5);
      expect(service.consumed(project), isEmpty);
    });
  });

  group("sao lưu", () {
    test("v4: giữ nhật ký kho và số đang về", () async {
      final (_, variants) = await createComponent("Trở 10K");
      final v = variants[""]!;
      final repo = VariantRepository();
      await repo.adjustStock(v.id, 4);
      await repo.addIncoming({v.id: 9});

      final transfer = DataTransferService();
      final data = jsonDecode(jsonEncode(transfer.exportAll()));
      expect(data["version"], 4);
      transfer.replaceAll(data as Map<String, dynamic>);

      final restored = db.get<ComponentVariant>().getAll().single;
      expect(restored.stock, 4);
      expect(restored.incoming, 9);
      final log = db.get<StockLog>().getAll().single;
      expect(log.variant.targetId, restored.id);
      expect((log.before, log.after), (null, 4));
    });

    test("xoá biến thể rồi hoàn tác: nhật ký nối lại", () async {
      final (_, variants) = await createComponent(
        "Còi",
        attributes: const [
          VariantAttribute("Điện áp", ["5V", "12V"]),
        ],
        variants: const [
          {"Điện áp": "5V"},
          {"Điện áp": "12V"},
        ],
      );
      final v = variants["5V"]!;
      await VariantRepository().adjustStock(v.id, 2);
      final transfer = DataTransferService();
      final snapshot = transfer.snapshot(variantIds: [v.id]);
      await VariantRepository().delete(v.id);
      transfer.restore(snapshot);

      final restored = db.get<ComponentVariant>().getAll().firstWhere(
        (x) => x.selection["Điện áp"] == "5V",
      );
      expect(restored.id, isNot(v.id));
      expect(logsOf(restored), hasLength(1));
    });
  });
}
