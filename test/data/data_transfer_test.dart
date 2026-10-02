import 'dart:convert';

import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/data/project_repository.dart';
import 'package:component_companion/data/stock_repository.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late dynamic dir;

  setUp(() async {
    final opened = await openTestDb();
    db = opened.$1;
    dir = opened.$2;
  });
  tearDown(() => closeTestDb(db, dir));

  /// Linh kiện "Nút nhấn" (Màu: Đỏ/Xanh) + 1 tuỳ chọn + tồn kho + 1 dự án dùng nó.
  Future<(int componentId, int optionId, int projectId)> seed() async {
    final categoryId = db.get<Category>().put(
      Category(name: "Công tắc", colorValue: 0xFFFFD1DC),
    );
    final component = Component(name: "Nút nhấn 12mm")
      ..attributes = const [
        VariantAttribute("Màu", ["Đỏ", "Xanh"]),
      ]
      ..category.targetId = categoryId;
    final componentId = await ComponentRepository().add(component);
    final optionId = await ComponentOptionRepository().add(
      ComponentOption(
        name: "Gói 10",
        unitsPerPack: 10,
        pricePerPack: 20000,
        shop: "Shop A",
      )..component.targetId = componentId,
    );
    await StockRepository().adjust(componentId, {"Màu": "Đỏ"}, 7);

    final projectId = await ProjectRepository().add(Project(name: "Robot"));
    db.get<ProjectItem>().put(
      ProjectItem(quantity: 4)
        ..variant = {"Màu": "Đỏ"}
        ..component.targetId = componentId
        ..componentOption.targetId = optionId
        ..project.targetId = projectId,
    );
    return (componentId, optionId, projectId);
  }

  test(
    "thêm tuỳ chọn ghi lịch sử giá, đổi giá ghi thêm, giữ nguyên thì không",
    () async {
      final (_, optionId, _) = await seed();
      final repo = ComponentOptionRepository();
      expect(repo.priceHistory(optionId), hasLength(1));

      final option = db.get<ComponentOption>().get(optionId)!;
      option.name = "Gói 10 cái";
      await repo.update(option);
      expect(repo.priceHistory(optionId), hasLength(1));

      option.pricePerPack = 60000;
      await repo.update(option);
      final history = repo.priceHistory(optionId);
      expect(history.map((r) => r.pricePerPack), [20000, 60000]);

      await repo.confirmPrice(optionId);
      expect(repo.priceHistory(optionId), hasLength(3));
    },
  );

  test(
    "xoá linh kiện kéo theo tuỳ chọn, lịch sử giá, tồn kho; hoàn tác khôi phục và nối lại dự án",
    () async {
      final (componentId, _, projectId) = await seed();
      final transfer = DataTransferService();

      final snapshot = transfer.snapshot(componentIds: [componentId]);
      await ComponentRepository().delete(componentId);
      expect(db.get<Component>().count(), 0);
      expect(db.get<ComponentOption>().count(), 0);
      expect(db.get<PriceRecord>().count(), 0);
      expect(db.get<StockItem>().count(), 0);

      transfer.restore(snapshot);
      final restored = db.get<Component>().getAll().single;
      expect(restored.name, "Nút nhấn 12mm");
      expect(restored.attributes.single.values, ["Đỏ", "Xanh"]);
      expect(restored.stockOf({"Màu": "Đỏ"}), 7);
      expect(restored.options.single.shop, "Shop A");
      expect(restored.options.single.priceHistory, hasLength(1));

      // Linh kiện trong dự án (không bị xoá) phải trỏ sang id mới
      final item = db.get<ProjectItem>().getAll().single;
      expect(item.project.targetId, projectId);
      expect(item.component.targetId, restored.id);
      expect(item.componentOption.targetId, restored.options.single.id);
      expect(item.variant, {"Màu": "Đỏ"});
    },
  );

  test(
    "xoá dự án kéo theo linh kiện trong dự án; hoàn tác khôi phục",
    () async {
      final (componentId, _, projectId) = await seed();
      final transfer = DataTransferService();

      final snapshot = transfer.snapshot(projectIds: [projectId]);
      await ProjectRepository().delete(projectId);
      expect(db.get<ProjectItem>().count(), 0);

      transfer.restore(snapshot);
      final item = db.get<ProjectItem>().getAll().single;
      expect(item.project.target?.name, "Robot");
      expect(item.component.targetId, componentId);
    },
  );

  test(
    "sao lưu ra JSON rồi khôi phục vào DB trống giữ nguyên quan hệ",
    () async {
      await seed();
      final transfer = DataTransferService();
      final json = jsonEncode(transfer.exportAll());

      final data = jsonDecode(json);
      expect(DataTransferService.validate(data), isNull);
      transfer.replaceAll(data as Map<String, dynamic>);

      final component = db.get<Component>().getAll().single;
      expect(component.category.target?.name, "Công tắc");
      expect(component.stockTotal, 7);
      final item = db.get<ProjectItem>().getAll().single;
      expect(item.component.target?.name, "Nút nhấn 12mm");
      expect(item.componentOption.target?.pricePerPack, 20000);
      expect(item.project.target?.name, "Robot");
    },
  );

  test("nhân bản linh kiện giữ biến thể, shop, phạm vi áp dụng", () async {
    final (componentId, optionId, _) = await seed();
    final option = db.get<ComponentOption>().get(optionId)!
      ..availability = {
        "Màu": ["Đỏ"],
      };
    await ComponentOptionRepository().update(option);

    final cloneId = await ComponentRepository().clone(componentId);
    final clone = db.get<Component>().get(cloneId)!;
    expect(clone.name, "Nút nhấn 12mm (bản sao)");
    expect(clone.attributes, db.get<Component>().get(componentId)!.attributes);
    expect(clone.options.single.shop, "Shop A");
    expect(clone.options.single.availability, {
      "Màu": ["Đỏ"],
    });
    expect(clone.stockTotal, isNull); // không nhân bản tồn kho
  });

  test("bỏ một giá trị thuộc tính thì dọn phạm vi áp dụng và tồn kho", () async {
    final (componentId, optionId, _) = await seed();
    final option = db.get<ComponentOption>().get(optionId)!
      ..availability = {
        "Màu": ["Đỏ"],
      };
    await ComponentOptionRepository().update(option);

    final component = db.get<Component>().get(componentId)!
      ..attributes = const [
        VariantAttribute("Màu", ["Xanh", "Vàng"]),
      ];
    await ComponentRepository().update(component);

    // "Đỏ" không còn => tuỳ chọn áp dụng cho mọi màu, tồn kho đỏ thành "không biến thể"
    expect(db.get<ComponentOption>().get(optionId)!.availability, isEmpty);
    final stock = db.get<StockItem>().getAll().single;
    expect(stock.variant, isEmpty);
    expect(stock.quantity, 7);
  });

  test("xoá + hoàn tác linh kiện chưa có tuỳ chọn / tồn kho", () async {
    final id = await ComponentRepository().add(Component(name: "Tụ gốm 104"));
    final transfer = DataTransferService();
    final snapshot = transfer.snapshot(componentIds: [id]);
    expect(await ComponentRepository().delete(id), isTrue);
    expect(db.get<Component>().count(), 0);
    transfer.restore(snapshot);
    expect(db.get<Component>().getAll().single.name, "Tụ gốm 104");
  });
}
