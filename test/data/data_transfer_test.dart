import 'dart:convert';
import 'dart:io';

import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/data/project_repository.dart';
import 'package:component_companion/data/shop_repository.dart';
import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  /// Còi (Điện áp x Kiểu) có 2 biến thể, 1 tuỳ chọn cho cả 2, 1 dự án dùng 5V.
  Future<
    ({
      Component component,
      ComponentVariant v5,
      ComponentVariant v12,
      int optionId,
      int projectId,
    })
  >
  seed() async {
    final categoryId = db.get<Category>().put(
      Category(name: "Thụ động", colorValue: 0xFFFFD1DC),
    );
    final (component, variants) = await createComponent(
      "Còi chip",
      attributes: const [
        VariantAttribute("Điện áp", ["5V", "12V"]),
      ],
      variants: const [
        {"Điện áp": "5V"},
        {"Điện áp": "12V"},
      ],
    );
    component.category.targetId = categoryId;
    db.get<Component>().put(component);
    final v5 = variants["5V"]!..stock = 7;
    final v12 = variants["12V"]!;
    db.get<ComponentVariant>().put(v5);
    final optionId = await addOffer(
      component,
      [v5, v12],
      name: "Gói 10",
      units: 10,
      price: 20000,
      shop: "Shop A",
    );
    final projectId = await ProjectRepository().add(Project(name: "Robot"));
    db.get<ProjectItem>().put(
      ProjectItem(quantity: 4)
        ..component.targetId = component.id
        ..variant.targetId = v5.id
        ..componentOption.targetId = optionId
        ..project.targetId = projectId,
    );
    return (
      component: db.get<Component>().get(component.id)!,
      v5: v5,
      v12: v12,
      optionId: optionId,
      projectId: projectId,
    );
  }

  group("lịch sử giá", () {
    test("chỉ đổi giá => ghi thêm; xác nhận giá => ghi thêm", () async {
      final s = await seed();
      final repo = ComponentOptionRepository();
      final option = db.get<ComponentOption>().get(s.optionId)!;
      option.pricePerPack = 60000;
      await repo.update(option);
      expect(repo.priceHistory(s.optionId).map((r) => r.pricePerPack), [
        20000,
        60000,
      ]);
      await repo.confirmPrice(s.optionId);
      expect(repo.priceHistory(s.optionId), hasLength(3));
    });

    test(
      "đổi shop / quy cách => coi là chào giá khác, lịch sử bắt đầu lại",
      () async {
        final s = await seed();
        final repo = ComponentOptionRepository();
        final option = db.get<ComponentOption>().get(s.optionId)!
          ..pricePerPack = 25000;
        await repo.update(option);
        expect(repo.priceHistory(s.optionId), hasLength(2));

        option
          ..shop.target = ShopRepository().findOrCreate("Shop B")
          ..pricePerPack = 18000;
        await repo.update(option);
        final history = repo.priceHistory(s.optionId);
        expect(history.map((r) => r.pricePerPack), [18000]);
      },
    );
  });

  group("trùng tên tuỳ chọn", () {
    test("cùng tên + shop + quy cách nhưng khác biến thể => hợp lệ", () async {
      final s = await seed();
      // "Gói 10" của Shop A cho riêng 12V với giá khác
      await expectLater(
        addOffer(
          s.component,
          [s.v12],
          name: "Gói 10",
          units: 10,
          price: 30000,
          shop: "Shop A",
        ),
        completes,
      );
      // Trùng hoàn toàn (cùng tập biến thể) => báo trùng
      await expectLater(
        addOffer(
          s.component,
          [s.v5, s.v12],
          name: "Gói 10",
          units: 10,
          price: 1,
          shop: "Shop A",
        ),
        throwsA(anything),
      );
    });

    test("linh kiện có biến thể thì bắt buộc chọn biến thể", () async {
      final s = await seed();
      await expectLater(
        addOffer(s.component, const [], name: "X", units: 1, price: 1),
        throwsA(anything),
      );
    });
  });

  test(
    "xoá linh kiện kéo theo biến thể, tuỳ chọn, lịch sử; hoàn tác nối lại dự án",
    () async {
      final s = await seed();
      final transfer = DataTransferService();
      final snapshot = transfer.snapshot(componentIds: [s.component.id]);

      await ComponentRepository().delete(s.component.id);
      expect(db.get<Component>().count(), 0);
      expect(db.get<ComponentVariant>().count(), 0);
      expect(db.get<ComponentOption>().count(), 0);
      expect(db.get<PriceRecord>().count(), 0);

      transfer.restore(snapshot);
      final restored = db.get<Component>().getAll().single;
      final v5 = restored.variants.firstWhere(
        (v) => v.selection["Điện áp"] == "5V",
      );
      expect(v5.stock, 7);
      final option = restored.options.single;
      expect(option.shopName, "Shop A");
      expect(option.variants, hasLength(2));
      expect(option.priceHistory, hasLength(1));

      final item = db.get<ProjectItem>().getAll().single;
      expect(item.project.targetId, s.projectId);
      expect(item.component.targetId, restored.id);
      expect(item.variant.targetId, v5.id);
      expect(item.componentOption.targetId, option.id);
    },
  );

  test("xoá biến thể rồi hoàn tác: nối lại tuỳ chọn và dự án", () async {
    final s = await seed();
    final transfer = DataTransferService();
    final snapshot = transfer.snapshot(variantIds: [s.v5.id]);
    await VariantRepository().delete(s.v5.id);
    expect(db.get<ComponentOption>().get(s.optionId)!.variants, hasLength(1));

    transfer.restore(snapshot);
    final option = db.get<ComponentOption>().get(s.optionId)!;
    expect(option.variants, hasLength(2));
    final restored = option.variants.firstWhere(
      (v) => v.selection["Điện áp"] == "5V",
    );
    expect(restored.stock, 7);
    expect(db.get<ProjectItem>().getAll().single.variant.targetId, restored.id);
  });

  test("xoá shop rồi hoàn tác: tuỳ chọn trỏ lại shop", () async {
    await seed();
    final shopId = db.get<Shop>().getAll().single.id;
    final transfer = DataTransferService();
    final snapshot = transfer.snapshot(shopIds: [shopId]);
    await ShopRepository().delete(shopId);
    expect(db.get<ComponentOption>().getAll().single.shopName, "");
    transfer.restore(snapshot);
    expect(db.get<ComponentOption>().getAll().single.shopName, "Shop A");
  });

  test("sao lưu JSON rồi khôi phục vào DB trống giữ nguyên quan hệ", () async {
    await seed();
    final transfer = DataTransferService();
    final data = jsonDecode(jsonEncode(transfer.exportAll()));
    expect(DataTransferService.validate(data), isNull);
    transfer.replaceAll(data as Map<String, dynamic>);

    final component = db.get<Component>().getAll().single;
    expect(component.category.target?.name, "Thụ động");
    expect(component.stockTotal, 7);
    final option = component.options.single;
    expect(
      option.variants.map((v) => v.selection["Điện áp"]),
      unorderedEquals(["5V", "12V"]),
    );
    final item = db.get<ProjectItem>().getAll().single;
    expect(item.variant.target?.selection, {"Điện áp": "5V"});
    expect(item.componentOption.target?.shopName, "Shop A");
  });

  test("gộp shop chuyển hết tuỳ chọn", () async {
    final s = await seed();
    await addOffer(
      s.component,
      [s.v12],
      name: "Gói 1",
      units: 1,
      price: 3000,
      shop: "shop a ",
    );
    // "shop a " trùng "Shop A" (không phân biệt hoa thường, bỏ khoảng trắng)
    expect(db.get<Shop>().count(), 1);
    final b = await ShopRepository().add(Shop(name: "Shop B"));
    final a = db.get<Shop>().getAll().firstWhere((x) => x.name == "Shop A").id;
    expect(await ShopRepository().merge(a, b), 2);
    expect(db.get<ComponentOption>().getAll().map((o) => o.shopName).toSet(), {
      "Shop B",
    });
  });

  test(
    "nhân bản linh kiện giữ biến thể + tuỳ chọn, không giữ tồn kho",
    () async {
      final s = await seed();
      final cloneId = await ComponentRepository().clone(s.component.id);
      final clone = db.get<Component>().get(cloneId)!;
      expect(clone.variants, hasLength(2));
      expect(clone.stockTotal, isNull);
      final option = clone.options.single;
      expect(
        option.variants.every((v) => v.component.targetId == cloneId),
        isTrue,
      );
      expect(option.shopName, "Shop A");
    },
  );

  test(
    "bỏ thuộc tính => gộp biến thể: cộng kho, gộp tuỳ chọn, trỏ lại dự án",
    () async {
      final s = await seed();
      final v12 = db.get<ComponentVariant>().get(s.v12.id)!..stock = 3;
      db.get<ComponentVariant>().put(v12);

      final component = db.get<Component>().get(s.component.id)!
        ..attributes = const [];
      await ComponentRepository().update(component);

      final variant = db.get<ComponentVariant>().getAll().single;
      expect(variant.isDefault, isTrue);
      expect(variant.stock, 10);
      expect(
        db.get<ComponentOption>().get(s.optionId)!.variants.single.id,
        variant.id,
      );
      expect(
        db.get<ProjectItem>().getAll().single.variant.targetId,
        variant.id,
      );
    },
  );

  test(
    "linh kiện không thuộc tính tự có biến thể mặc định; xoá không lỗi",
    () async {
      final id = await ComponentRepository().add(Component(name: "Tụ gốm 104"));
      expect(db.get<Component>().get(id)!.variants.single.isDefault, isTrue);
      final transfer = DataTransferService();
      final snapshot = transfer.snapshot(componentIds: [id]);
      expect(await ComponentRepository().delete(id), isTrue);
      transfer.restore(snapshot);
      expect(db.get<Component>().getAll().single.variants, hasLength(1));
    },
  );
}
