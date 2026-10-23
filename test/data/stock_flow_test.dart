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
import 'package:component_companion/service/stock_reservation.dart';
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

  group("dự án nhớ đã lấy gì khỏi kho", () {
    test("chỉ trừ phần chưa trừ; trừ đủ rồi thì không còn gì để hỏi", () async {
      final (component, variants) = await createComponent("Trở 10K");
      final v = variants[""]!..stock = 20;
      db.get<ComponentVariant>().put(v);
      final id = db.get<Project>().put(Project(name: "Robot"));
      final itemId = db.get<ProjectItem>().put(
        ProjectItem(quantity: 6)
          ..component.targetId = component.id
          ..variant.targetId = v.id
          ..project.targetId = id,
      );
      final service = ProjectStockService();
      Project project() => db.get<Project>().get(id)!;

      service.consume(project(), service.remaining(project()));
      expect(reload(v).stock, 14);
      // Hoàn thành -> Lập kế hoạch -> Hoàn thành: không trừ lần 2
      expect(service.remaining(project()), isEmpty);

      // Tăng số lượng trong dự án => chỉ trừ thêm phần tăng
      db.get<ProjectItem>().put(
        db.get<ProjectItem>().get(itemId)!..quantity = 8,
      );
      expect(service.remaining(project()).single.quantity, 2);
      service.consume(project(), service.remaining(project()));
      expect(reload(v).stock, 12);
      expect(service.consumed(project()).single.quantity, 8);

      // Lưu trữ => trả hết về kho để tái sử dụng
      service.giveBack(project(), service.consumed(project()));
      expect(reload(v).stock, 20);
      expect(service.remaining(project()).single.quantity, 8);
    });

    test("cần mua + giữ hàng không tính phần dự án đã lấy", () async {
      final (component, variants) = await createComponent("Trở 10K");
      final v = variants[""]!..stock = 10;
      db.get<ComponentVariant>().put(v);
      await addOffer(component, [v], name: "1 cái", units: 1, price: 100);
      final id = db.get<Project>().put(
        Project(name: "Robot", status: ProjectStatus.inProgress.name),
      );
      db.get<ProjectItem>().put(
        ProjectItem(quantity: 6)
          ..component.targetId = component.id
          ..variant.targetId = v.id
          ..project.targetId = id,
      );
      final service = ProjectStockService();
      Project project() => db.get<Project>().get(id)!;
      final usage = service.usage(project());
      // Lấy trước 4 cái
      service.consume(project(), [
        ProjectStockLine(usage.single.component, usage.single.variant, 4),
      ]);
      expect(reload(v).stock, 6);

      final line = ShoppingList.build(
        project().configurationEntries,
        allocated: service.allocated([id]),
      ).single;
      expect(line.allocated, 4);
      expect(line.needed, 2);
      expect(line.isCovered, isTrue);

      final reservations = StockReservations.of(
        [project()],
        consumed: {id: StockLedger().consumedBy(id)},
      );
      expect(reservations.reserved(v.id), 2);
    });
  });

  group("đánh dấu đã trừ (dự án làm trước khi dùng app)", () {
    test("đánh dấu không đổi tồn kho; tháo dự án thì trả lại được", () async {
      final (component, variants) = await createComponent("Trở 10K");
      final v = variants[""]!..stock = 3;
      db.get<ComponentVariant>().put(v);
      final id = db.get<Project>().put(
        Project(name: "Đèn cũ", status: ProjectStatus.completed.name),
      );
      db.get<ProjectItem>().put(
        ProjectItem(quantity: 5)
          ..component.targetId = component.id
          ..variant.targetId = v.id
          ..project.targetId = id,
      );
      final service = ProjectStockService();
      Project project() => db.get<Project>().get(id)!;
      expect(service.status(project()), (consumed: 0, needed: 5));

      final marks = service.markConsumed(
        project(),
        service.remaining(project()),
      );
      expect(reload(v).stock, 3); // tồn kho không đổi
      expect(service.status(project()), (consumed: 5, needed: 5));
      expect(service.remaining(project()), isEmpty);
      expect(logsOf(v).first.stockReason, StockReason.projectMark);

      // Hoàn tác đánh dấu
      service.revert(project(), marks);
      expect(service.status(project()).consumed, 0);
      service.markConsumed(project(), service.remaining(project()));

      // Tháo dự án => trả về kho: cộng đúng 5 cái
      service.giveBack(project(), service.consumed(project()));
      expect(reload(v).stock, 8);
      expect(service.status(project()).consumed, 0);

      // Đánh dấu rồi bỏ đánh dấu: kho vẫn không đổi
      service.markConsumed(project(), service.remaining(project()));
      service.unmark(project(), service.consumed(project()));
      expect(reload(v).stock, 8);
      expect(service.consumed(project()), isEmpty);
    });
  });

  group("sao lưu", () {
    test("giữ nhật ký kho và số đang về", () async {
      final (_, variants) = await createComponent("Trở 10K");
      final v = variants[""]!;
      final repo = VariantRepository();
      await repo.adjustStock(v.id, 4);
      await repo.addIncoming({v.id: 9});

      final transfer = DataTransferService();
      final data = jsonDecode(jsonEncode(transfer.exportAll()));
      expect(data["version"], DataTransferService.version);
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
