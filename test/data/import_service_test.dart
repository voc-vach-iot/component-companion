import 'dart:io';

import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  test("đọc JSON dạng BOM (clean_name / variant)", () {
    final rows = ImportService.parse('''[
      {"raw_name": "Bộ 50 Công Tắc Rung", "clean_name": "Công tắc rung SW-18010P", "variant": "10PCS"},
      {"raw_name": "x", "clean_name": "Tụ hóa 100uF", "variant": ""}
    ]''');
    expect(rows.map((r) => r.name), [
      "Công tắc rung SW-18010P",
      "Tụ hóa 100uF",
    ]);
    expect(rows.first.packName, "10PCS");
  });

  test("đọc file mẫu: thuộc tính, giá có dấu chấm", () {
    final rows = ImportService.parse(ImportService.templateCsv());
    expect(rows, hasLength(4));
    expect(rows.first.attributes, {"Điện áp": "5V", "Kiểu": "Active"});
    expect(rows.first.packName, "Gói 5 cái");
    expect(rows.first.units, 5);
    expect(rows.first.price, 12000);
    expect(rows.first.shop, "Linh kiện ABC");

    final dot = ImportService.parse("Tên;Giá gói\nTrở;25.000đ").single;
    expect(dot.price, 25000);
  });

  test("báo lỗi khi không có cột tên", () {
    expect(() => ImportService.parse("a,b\n1,2"), throwsA(anything));
  });

  test("khoá link: cùng sản phẩm Shopee dù khác dạng link", () {
    expect(
      ImportService.linkKey("https://shopee.vn/Cam-bien-i.123.456?sp_atk=x"),
      "shopee:123.456",
    );
    expect(
      ImportService.linkKey("https://shopee.vn/product/123/456"),
      "shopee:123.456",
    );
    expect(
      ImportService.linkKey("https://www.Example.com/a/?q=1"),
      "example.com/a",
    );
    expect(ImportService.linkKey(""), "");
  });

  group("ghi vào DB", () {
    late ObjectboxService db;
    late Directory dir;
    setUp(() async => (db, dir) = await openTestDb());
    tearDown(() => closeTestDb(db, dir));

    test(
      "tạo linh kiện + biến thể, gộp tuỳ chọn cùng giá cho nhiều biến thể, cộng kho",
      () {
        final passive = db.get<Category>().put(
          Category(name: "Thụ động", colorValue: 0xFF000000, keywords: ["còi"]),
        );
        final service = ImportService();
        final plans = service.plan(
          ImportService.parse(ImportService.templateCsv()),
        );
        expect(plans.first.categoryId, passive);

        final result = service.apply(plans, addToStock: true);
        expect(result.created, 3);
        expect(result.variantsCreated, 4); // 2 còi + 1 trở + 1 mặc định ESP32

        final buzzer = db.get<Component>().getAll().firstWhere(
          (c) => c.name.startsWith("Còi"),
        );
        expect(buzzer.attributes.map((a) => a.name), ["Điện áp", "Kiểu"]);
        expect(buzzer.variants, hasLength(2));
        // 2 dòng cùng shop + phân loại + giá => 1 tuỳ chọn gắn 2 biến thể
        final offer = buzzer.options.single;
        expect(offer.variants, hasLength(2));
        // Link shopee.vn => shop có hậu tố (Shopee)
        expect(offer.shopName, "Linh kiện ABC (Shopee)");
        final v5 = buzzer.variants.firstWhere(
          (v) => v.selection["Điện áp"] == "5V",
        );
        expect(v5.stock, 5);

        final esp = db.get<Component>().getAll().firstWhere(
          (c) => c.name.startsWith("ESP32"),
        );
        expect(esp.variants.single.isDefault, isTrue);
        expect(esp.variants.single.stock, 3);
        expect(db.get<Shop>().count(), 2);

        // Nhập lại không tạo trùng tuỳ chọn / biến thể
        service.apply(
          service.plan(ImportService.parse(ImportService.templateCsv())),
        );
        expect(db.get<ComponentOption>().count(), 3);
        expect(db.get<Component>().get(buzzer.id)!.variants, hasLength(2));
      },
    );

    group("khớp linh kiện có sẵn", () {
      late int lm358;
      late int resistor;
      late int optionId;
      late int v10k;

      setUp(() {
        lm358 = db.get<Component>().put(Component(name: "LM358"));
        db.get<ComponentVariant>().put(
          ComponentVariant(selectionJson: Variants.encodeSelection(const {}))
            ..component.targetId = lm358,
        );
        resistor = db.get<Component>().put(
          Component(name: "Điện trở 0805")
            ..attributes = [
              const VariantAttribute("Giá trị", ["10K", "1K"]),
            ],
        );
        v10k = db.get<ComponentVariant>().put(
          ComponentVariant(
            selectionJson: Variants.encodeSelection(const {"Giá trị": "10K"}),
          )..component.targetId = resistor,
        );
        db.get<ComponentVariant>().put(
          ComponentVariant(
            selectionJson: Variants.encodeSelection(const {"Giá trị": "1K"}),
          )..component.targetId = resistor,
        );
        final option =
            ComponentOption(
                name: "Gói 10 cái",
                unitsPerPack: 10,
                pricePerPack: 20000,
                link: "https://shopee.vn/LM358-DIP8-i.11.22",
              )
              ..component.targetId = lm358
              ..variants.add(db.get<Component>().get(lm358)!.variants.single);
        optionId = db.get<ComponentOption>().put(option);
        db.get<PriceRecord>().put(
          PriceRecord(pricePerPack: 20000, unitsPerPack: 10)
            ..option.targetId = optionId,
        );
      });

      List<ImportPlan> plan(String csv) =>
          ImportService().plan(ImportService.parse(csv));

      test("dòng trùng link => cập nhật giá, giá cũ vào lịch sử", () {
        final p = plan(
          "Tên linh kiện,Phân loại,Số cái/gói,Giá gói,Link\n"
          "IC khuếch đại thuật toán DIP-8,Gói 10 cái,10,25000,"
          "https://shopee.vn/product/11/22",
        ).single;
        expect(p.match, ImportMatch.link);
        expect(p.existing?.id, lm358);
        expect(p.linkedOption?.id, optionId);

        final result = ImportService().apply([p]);
        expect(result.created, 0);
        expect(result.optionsAdded, 0);
        expect(result.pricesUpdated, 1);
        final option = db.get<ComponentOption>().get(optionId)!;
        expect(option.pricePerPack, 25000);
        expect(option.sortedPriceHistory.map((r) => r.pricePerPack), [
          20000,
          25000,
        ]);
      });

      test("cùng link, phân loại khác => tuỳ chọn mới, không gộp giá", () {
        // Tuỳ chọn có sẵn của biến thể 10K (từ trang sản phẩm: phân loại
        // nằm ở cột thuộc tính, tên tuỳ chọn mặc định "Gói 100 cái")
        final link = "https://shopee.vn/Dien-tro-i.33.44";
        final option10k = db.get<ComponentOption>().put(
          ComponentOption(
              name: "Gói 100 cái",
              unitsPerPack: 100,
              pricePerPack: 10000,
              link: link,
            )
            ..component.targetId = resistor
            ..variants.add(db.get<ComponentVariant>().get(v10k)!),
        );
        final plans = plan(
          "Tên linh kiện,Thuộc tính,Số cái/gói,Giá gói,Link\n"
          "Điện trở 0805,Giá trị=10K,100,11000,$link\n"
          "Điện trở 0805,Giá trị=1K,100,12000,$link",
        );
        expect(plans.map((p) => p.existing?.id), [resistor, resistor]);
        expect(plans[0].linkedOption?.id, option10k);
        expect(plans[1].linkedOption, isNull);

        final result = ImportService().apply(plans);
        expect(result.pricesUpdated, 1);
        expect(result.optionsAdded, 1);
        final old = db.get<ComponentOption>().get(option10k)!;
        expect(old.pricePerPack, 11000);
        expect(old.variants.map((v) => v.selection["Giá trị"]), ["10K"]);
        final added = db
            .get<ComponentOption>()
            .getAll()
            .where((o) => o.link == link && o.id != option10k)
            .single;
        expect(added.pricePerPack, 12000);
        expect(added.variants.map((v) => v.selection["Giá trị"]), ["1K"]);
      });

      test("dòng đoán theo tên => khớp linh kiện + biến thể", () {
        final p = plan(
          "Tên linh kiện,Phân loại,Giá gói,Shop\n"
          "Bộ 100 con điện trở dán 0805 1%,10K,15000,Shop A",
        ).single;
        expect(p.match, ImportMatch.guess);
        expect(p.existing?.id, resistor);
        expect(p.variantId, v10k);

        final result = ImportService().apply([p]);
        expect(result.created, 0);
        expect(result.variantsCreated, 0);
        expect(result.optionsAdded, 1);
        final option = db.get<ComponentOption>().getAll().firstWhere(
          (o) => o.component.targetId == resistor,
        );
        expect(option.variants.map((v) => v.id), [v10k]);
        // Không thêm thuộc tính lạ vào linh kiện có sẵn
        expect(
          db.get<Component>().get(resistor)!.attributes.single.name,
          "Giá trị",
        );
      });

      test("dòng không giống => tạo mới; hoàn tác trả lại như cũ", () {
        final plans = plan(
          "Tên linh kiện,Phân loại,Số cái/gói,Giá gói,Số lượng mua,Shop,Link\n"
          "Cảm biến nhiệt độ DS18B20,1 cái,1,30000,2,Shop B,\n"
          "IC khuếch đại DIP-8,Gói 10 cái,10,25000,1,,https://shopee.vn/x-i.11.22",
        );
        expect(plans.first.match, ImportMatch.none);
        expect(plans.first.existing, isNull);
        expect(plans.last.linkedOption?.id, optionId);

        final service = ImportService();
        final before = (
          db.get<Component>().count(),
          db.get<ComponentVariant>().count(),
          db.get<ComponentOption>().count(),
          db.get<PriceRecord>().count(),
        );
        final result = service.apply(plans, addToStock: true);
        expect(result.created, 1);
        expect(result.pricesUpdated, 1);
        expect(result.stocked, 2);
        final lmVariant = db.get<Component>().get(lm358)!.variants.single;
        expect(lmVariant.stock, 10);

        service.undo(result.undo);
        expect((
          db.get<Component>().count(),
          db.get<ComponentVariant>().count(),
          db.get<ComponentOption>().count(),
          db.get<PriceRecord>().count(),
        ), before);
        expect(db.get<Shop>().count(), 0);
        expect(db.get<ComponentOption>().get(optionId)!.pricePerPack, 20000);
        expect(db.get<ComponentVariant>().get(lmVariant.id)!.stock, isNull);
      });

      test("chọn tay linh kiện khác / tạo mới", () {
        final p = plan("Tên linh kiện\nLM358 DIP8").single;
        expect(p.existing?.id, lm358);
        p.selectComponent(null);
        expect(p.existing, isNull);
        expect(p.match, ImportMatch.none);
        p.selectComponent(db.get<Component>().get(resistor));
        expect(p.match, ImportMatch.manual);
        expect(p.variantId, isNull); // không đoán được giá trị
      });

      test("dòng đã khớp: tạo mới rồi quay lại gợi ý", () {
        final p = plan(
          "Tên linh kiện,Phân loại,Số cái/gói,Giá gói,Link\n"
          "IC khuếch đại DIP-8,Gói 10 cái,10,25000,"
          "https://shopee.vn/product/11/22",
        ).single;
        expect(p.usesSuggestion, isTrue);

        p.createNew();
        expect(p.existing, isNull);
        expect(p.linkedOption, isNull);
        expect(p.name, "IC khuếch đại DIP-8");
        final created = ImportService().apply([p]);
        expect(created.created, 1);
        ImportService().undo(created.undo);

        p.useSuggestion();
        expect(p.existing?.id, lm358);
        expect(p.match, ImportMatch.link);
        expect(p.linkedOption?.id, optionId);
        expect(ImportService().apply([p]).pricesUpdated, 1);
      });
    });

    group("đơn hàng Shopee", () {
      const header =
          "Tên linh kiện,Phân loại,Số cái/gói,Giá gói,Số lượng mua,Shop,Link,Trạng thái,Nguồn\n";

      test(
        "trạng thái đơn: đã nhận => kho, chưa giao => đang về, huỷ => bỏ qua",
        () {
          final rows = ImportService.parse(
            "$header"
            "Trở 10K,Gói 10,10,5000,2,Shop A,,Hoàn thành,Shopee\n"
            "Tụ 100nF,Gói 10,10,5000,1,Shop A,,Chờ giao hàng,Shopee\n"
            "LED đỏ,Gói 10,10,5000,3,Shop A,,Đã hủy,Shopee",
          );
          expect(rows.map((r) => r.delivery), [
            ImportDelivery.received,
            ImportDelivery.pending,
            ImportDelivery.cancelled,
          ]);
          final service = ImportService();
          final result = service.apply(service.plan(rows), addToStock: true);
          expect(result.stocked, 1);
          expect(result.incoming, 1);
          expect(result.componentIds, hasLength(3));

          ComponentVariant variantOf(String name) => db
              .get<Component>()
              .getAll()
              .firstWhere((c) => c.name == name)
              .variants
              .single;
          expect(variantOf("Trở 10K").stock, 20);
          expect(variantOf("Tụ 100nF").stock, isNull);
          expect(variantOf("Tụ 100nF").incoming, 10);
          expect(variantOf("LED đỏ").stock, isNull);
          expect(variantOf("LED đỏ").incoming, 0);

          service.undo(result.undo);
          expect(db.get<Component>().count(), 0);
        },
      );

      test("shop Shopee: thêm hậu tố, không thêm 2 lần, đổi tên shop cũ", () {
        final old = db.get<Shop>().put(Shop(name: "Flash Electric"));
        final rows = ImportService.parse(
          "$header"
          "Trở 10K,Gói 10,10,5000,0,Flash Electric,,,Shopee\n"
          "Tụ 100nF,Gói 10,10,6000,0,Flash Electric (shopee),,,\n"
          "LED đỏ,Gói 10,10,7000,0,Linh kiện XYZ,https://shopee.vn/a-i.1.2,,\n"
          "Còi,Gói 1,1,7000,0,Cửa hàng ngoài,,,",
        );
        expect(rows.map((r) => r.shopName), [
          "Flash Electric (Shopee)",
          "Flash Electric (Shopee)",
          "Linh kiện XYZ (Shopee)",
          "Cửa hàng ngoài",
        ]);
        final service = ImportService();
        final plans = service.plan(rows);
        expect(service.shopHints(plans), [
          (from: "Flash Electric", to: "Flash Electric (Shopee)", merge: false),
        ]);

        final result = service.apply(plans);
        final names = db.get<Shop>().getAll().map((s) => s.name).toList();
        expect(
          names,
          unorderedEquals([
            "Flash Electric (Shopee)",
            "Linh kiện XYZ (Shopee)",
            "Cửa hàng ngoài",
          ]),
        );
        // Shop cũ được đổi tên (giữ id) chứ không tạo shop mới
        expect(db.get<Shop>().get(old)!.name, "Flash Electric (Shopee)");

        service.undo(result.undo);
        expect(db.get<Shop>().getAll().map((s) => s.name), ["Flash Electric"]);
      });

      test("không đổi tên shop cũ nếu tắt; có cả 2 tên => gợi ý gộp", () {
        db.get<Shop>().put(Shop(name: "Flash Electric"));
        final rows = ImportService.parse(
          "${header}Trở 10K,Gói 10,10,5000,0,Flash Electric,,,Shopee",
        );
        final service = ImportService();
        service.apply(service.plan(rows), renameShops: false);
        expect(db.get<Shop>().getAll().single.name, "Flash Electric");

        db.get<Shop>().put(Shop(name: "Flash Electric (Shopee)"));
        expect(service.shopHints(service.plan(rows)).single.merge, isTrue);
      });
    });

    group("nhiều phân loại của 1 sản phẩm (thẻ nhớ)", () {
      const name = "Thẻ nhớ MicroSD Kingston Class 10 16GB/32GB/64GB";

      List<ImportPlan> planRows(List<String> packs) => ImportService().plan(
        ImportService.parse(
          "Tên linh kiện,Phân loại,Số cái/gói,Giá gói,Shop\n"
          "${packs.map((p) => "$name,$p,1,50000,Shop A").join("\n")}",
        ),
      );

      test("tạo linh kiện + biến thể ở dòng đầu, các dòng sau tự theo", () {
        final plans = planRows(["16GB", "64GB", "32GB"]);
        final session = ImportSession(plans);

        // Đặt tên linh kiện mới ở dòng đầu => cả 3 dòng cùng sản phẩm
        expect(
          session.setTarget(plans[0], null, newName: "Thẻ nhớ MicroSD"),
          3,
        );
        expect(plans.map((p) => p.name).toSet(), {"Thẻ nhớ MicroSD"});
        expect(session.newNames(), ["Thẻ nhớ MicroSD"]);

        // Biến thể mới ở dòng đầu => đoán cho 2 dòng còn lại theo cột Phân loại
        expect(session.setVariant(plans[0], {"Dung lượng": "16GB"}), 2);
        expect(plans.map((p) => p.attributes["Dung lượng"]), [
          "16GB",
          "64GB",
          "32GB",
        ]);
        expect(session.pendingVariants(plans[1]).map((s) => s["Dung lượng"]), [
          "16GB",
          "32GB",
          "64GB",
        ]);

        final result = ImportService().apply(plans);
        expect(result.created, 1);
        expect(result.variantsCreated, 3);
        final card = db.get<Component>().getAll().single;
        expect(card.name, "Thẻ nhớ MicroSD");
        // Giá trị được sắp xếp tự nhiên
        expect(card.attributes.single.values, ["16GB", "32GB", "64GB"]);
        expect(card.sortedVariants.map((v) => v.selection["Dung lượng"]), [
          "16GB",
          "32GB",
          "64GB",
        ]);
      });

      test(
        "linh kiện có sẵn: biến thể đoán theo mẫu, trùng thì chọn biến thể có sẵn",
        () {
          final cardId = db.get<Component>().put(
            Component(name: "Thẻ nhớ MicroSD")
              ..attributes = const [
                VariantAttribute("Dung lượng", ["8GB", "128GB"]),
              ],
          );
          final v8 = db.get<ComponentVariant>().put(
            ComponentVariant(
              selectionJson: Variants.encodeSelection(const {
                "Dung lượng": "8GB",
              }),
            )..component.targetId = cardId,
          );
          final plans = planRows(["Thẻ 16GB", "Thẻ 32 GB", "Thẻ 8GB"]);
          final session = ImportSession(plans);
          session.setTarget(plans[0], db.get<Component>().get(cardId));
          expect(plans.every((p) => p.existing?.id == cardId), isTrue);

          // "Thẻ 8GB" đã tự chọn biến thể 8GB có sẵn => chỉ điền thêm 1 dòng
          expect(plans[2].variantId, v8);
          expect(session.setVariant(plans[0], {"Dung lượng": "16GB"}), 1);
          expect(plans[1].attributes["Dung lượng"], "32 GB");
          expect(plans[2].variantId, v8);

          ImportService().apply(plans);
          final card = db.get<Component>().get(cardId)!;
          expect(card.attributes.single.values, [
            "8GB",
            "16GB",
            "32 GB",
            "128GB",
          ]);
          expect(card.variants, hasLength(3));
        },
      );

      test("đổi riêng từng dòng / hoàn tác các dòng cùng sản phẩm", () {
        final a = db.get<Component>().put(Component(name: "Đầu đọc USB"));
        final b = db.get<Component>().put(Component(name: "Adapter SD"));
        final plans = planRows(["16GB", "32GB", "64GB"]);
        final session = ImportSession(plans);
        final before = [for (final p in plans) p.targetState];

        session.setTarget(plans[0], db.get<Component>().get(a));
        expect(plans.every((p) => p.existing?.id == a), isTrue);
        // Hoàn tác các dòng khác => chỉ dòng đầu đổi
        for (var i = 1; i < plans.length; i++) {
          plans[i].restoreTarget(before[i]);
        }
        expect(plans.map((p) => p.existing?.id), [a, null, null]);
        expect(plans[1].name, before[1].name);

        expect(
          session.setTarget(
            plans[1],
            db.get<Component>().get(b),
            sameProduct: false,
          ),
          1,
        );
        expect(plans.map((p) => p.existing?.id), [a, b, null]);
      });

      test("không tự thêm thuộc tính lạ của Shopee vào linh kiện có sẵn", () {
        final cardId = db.get<Component>().put(
          Component(name: "Thẻ nhớ MicroSD")
            ..attributes = const [
              VariantAttribute("Dung lượng thẻ", ["8GB"]),
            ],
        );
        final rows = ImportService.parse(
          "Tên linh kiện,Thuộc tính,Giá gói\n"
          "Thẻ nhớ MicroSD,Dung lượng=16GB,50000",
        );
        final plan = ImportService().plan(rows).single;
        expect(plan.existing?.id, cardId);
        ImportService().apply([plan]);
        expect(db.get<Component>().get(cardId)!.attributes.map((a) => a.name), [
          "Dung lượng thẻ",
        ]);
      });
    });
  });
}
