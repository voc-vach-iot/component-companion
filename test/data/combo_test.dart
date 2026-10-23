import 'dart:convert';
import 'dart:io';

import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/model/entities/combo_part.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/dashboard_service.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/ai/combo_assistant.dart';
import 'package:component_companion/util/bom_parser.dart';
import 'package:component_companion/util/component_search.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  ComponentOption reload(int id) => db.get<ComponentOption>().get(id)!;

  /// Thêm combo [parts] (biến thể, số cái) cho linh kiện [owner].
  Future<int> addCombo(
    Component owner,
    List<(ComponentVariant, int)> parts, {
    required String name,
    required int price,
    String link = "",
  }) {
    final option = ComponentOption(name: name, pricePerPack: price, link: link)
      ..component.targetId = owner.id
      ..draftParts = [
        for (final (v, q) in parts)
          ComboPart(quantity: q)..variant.targetId = v.id,
      ];
    return ComponentOptionRepository().add(option);
  }

  int projectWith(List<(Component, ComponentVariant, int)> items) {
    final id = db.get<Project>().put(Project(name: "Đồng hồ"));
    for (final (c, v, q) in items) {
      db.get<ProjectItem>().put(
        ProjectItem(quantity: q)
          ..component.targetId = c.id
          ..variant.targetId = v.id
          ..project.targetId = id,
      );
    }
    return id;
  }

  List<ShoppingLine> shopping(int projectId) => ShoppingList.build(
    db.get<Project>().get(projectId)!.configurationEntries,
  );

  group("LCD1602 + module I2C", () {
    late Component lcd;
    late Component i2c;
    late ComponentVariant vLcd;
    late ComponentVariant vI2c;
    late int combo;

    setUp(() async {
      final (a, va) = await createComponent("LCD1602");
      final (b, vb) = await createComponent("Module PCF8574");
      lcd = a;
      i2c = b;
      vLcd = va[""]!;
      vI2c = vb[""]!;
      await addOffer(lcd, [vLcd], name: "1 cái", units: 1, price: 40000);
      await addOffer(i2c, [vI2c], name: "1 cái", units: 1, price: 20000);
      combo = await addCombo(
        lcd,
        [(vLcd, 1), (vI2c, 1)],
        name: "Combo LCD + I2C",
        price: 54000,
      );
    });

    test("lưu combo: hiện ở cả 2 linh kiện, chia giá theo giá lẻ", () {
      final o = reload(combo);
      expect(o.isCombo, isTrue);
      expect(o.unitsPerPack, 1);
      expect(o.variants.map((v) => v.id), unorderedEquals([vLcd.id, vI2c.id]));
      expect(o.contentsLabel, "LCD1602 ×1 + Module PCF8574 ×1");
      // Combo có trong tuỳ chọn của biến thể PCF8574 (linh kiện khác)
      expect(
        db.get<ComponentVariant>().get(vI2c.id)!.options.map((x) => x.id),
        contains(combo),
      );
      // 40k : 20k => LCD 36k, I2C 18k
      expect(o.unitPriceFor(vLcd.id), closeTo(36000, 0.5));
      expect(o.unitPriceFor(vI2c.id), closeTo(18000, 0.5));
      expect(o.unitsFor(vLcd.id), 1);
      // "từ X/cái" của PCF8574 tính cả combo
      expect(
        ComponentRepository.cheapestUnitPrice(db.get<Component>().get(i2c.id)!),
        closeTo(18000, 0.5),
      );
    });

    test("cần cả 2 => mua combo 1 lần, tiền chia 2 dòng", () {
      final lines = shopping(projectWith([(lcd, vLcd, 1), (i2c, vI2c, 1)]));
      expect(lines.every((l) => l.plan.hasCombo), isTrue);
      expect(lines.fold(0, (s, l) => s + l.cost), 54000);
      final lcdLine = lines.firstWhere((l) => l.variant.id == vLcd.id);
      expect(lcdLine.cost, 36000);
      expect(lcdLine.plan.sharedWith, ["Module PCF8574"]);
      // Nhập kho combo chỉ tính 1 lần
      expect(ShoppingList.receivedUnits(lines), {vLcd.id: 1, vI2c.id: 1});
    });

    test("chỉ cần LCD => mua lẻ rẻ hơn combo", () {
      final line = shopping(projectWith([(lcd, vLcd, 1)])).single;
      expect(line.plan.hasCombo, isFalse);
      expect(line.cost, 40000);
    });

    test(
      "dự án chọn sẵn combo => vẫn mua combo khi không chọn giá rẻ nhất",
      () {
        final id = projectWith([(lcd, vLcd, 1)]);
        final item = db.get<ProjectItem>().getAll().single
          ..componentOption.targetId = combo;
        db.get<ProjectItem>().put(item);
        final line = ShoppingList.build(
          db.get<Project>().get(id)!.configurationEntries,
        ).single;
        expect(line.plan.hasCombo, isTrue);
        expect(line.cost, 54000);
        // Thành tiền trong dự án theo phần giá chia
        expect(
          db.get<ProjectItem>().get(item.id)!.totalPrice,
          closeTo(36000, 1),
        );
        // Mua combo khi chỉ cần LCD vẫn nhận cả module I2C
        expect(ShoppingList.receivedUnits([line]), {vLcd.id: 1, vI2c.id: 1});
      },
    );

    test("sao lưu + khôi phục giữ thành phần combo", () {
      final transfer = DataTransferService();
      final data = jsonDecode(jsonEncode(transfer.exportAll()));
      transfer.replaceAll(data as Map<String, dynamic>);
      final o = db.get<ComponentOption>().getAll().firstWhere((x) => x.isCombo);
      expect(o.contentsLabel, "LCD1602 ×1 + Module PCF8574 ×1");
      expect(db.get<ComboPart>().count(), 2);
    });

    test("xoá linh kiện có trong combo rồi hoàn tác: combo nối lại", () async {
      final transfer = DataTransferService();
      final snapshot = transfer.snapshot(componentIds: [i2c.id]);
      await ComponentRepository().delete(i2c.id);
      expect(reload(combo).contentsLabel, contains("(đã xoá)"));

      transfer.restore(snapshot);
      final restored = reload(combo);
      expect(restored.contentsLabel, "LCD1602 ×1 + Module PCF8574 ×1");
      expect(restored.variants, hasLength(2));
    });

    test("xoá linh kiện tạo combo => xoá luôn thành phần combo", () async {
      await ComponentRepository().delete(lcd.id);
      expect(db.get<ComponentOption>().get(combo), isNull);
      expect(db.get<ComboPart>().count(), 0);
    });

    test("bỏ combo (về tuỳ chọn thường) xoá thành phần", () async {
      final o = reload(combo)
        ..draftParts = const []
        ..variants.clear()
        ..variants.add(db.get<ComponentVariant>().get(vLcd.id)!);
      await ComponentOptionRepository().update(o);
      expect(reload(combo).isCombo, isFalse);
      expect(db.get<ComboPart>().count(), 0);
    });
  });

  group("XT60 1 cặp / mua lẻ", () {
    late Component xt60;
    late ComponentVariant male;
    late ComponentVariant female;

    setUp(() async {
      final (c, v) = await createComponent(
        "Jack XT60",
        attributes: const [
          VariantAttribute("Đầu", ["Đực", "Cái"]),
        ],
        variants: const [
          {"Đầu": "Đực"},
          {"Đầu": "Cái"},
        ],
      );
      xt60 = c;
      male = v["Đực"]!;
      female = v["Cái"]!;
      await addCombo(
        xt60,
        [(male, 1), (female, 1)],
        name: "1 cặp",
        price: 15000,
      );
    });

    test("2 đực + 2 cái => 2 cặp rẻ hơn mua lẻ", () async {
      await addOffer(
        xt60,
        [male, female],
        name: "1 cái",
        units: 1,
        price: 10000,
      );
      final lines = shopping(projectWith([(xt60, male, 2), (xt60, female, 2)]));
      expect(lines.every((l) => l.plan.hasCombo), isTrue);
      expect(lines.fold(0, (s, l) => s + l.cost), 30000);
      expect(lines.first.plan.parts.single.packs, 2);
    });

    test("chỉ có cặp, cần 1 đực => mua cặp, kho cộng cả đầu cái", () async {
      final id = projectWith([(xt60, male, 1)]);
      final line = shopping(id).single;
      expect(line.plan.hasCombo, isTrue);
      expect(line.cost, 15000);
      final received = ShoppingList.receivedUnits([line]);
      expect(received, {male.id: 1, female.id: 1});
      for (final e in received.entries) {
        await VariantRepository().adjustStock(e.key, e.value);
      }
      expect(db.get<ComponentVariant>().get(female.id)!.stock, 1);
    });

    test("giá trị kho: biến thể chỉ có combo tính theo giá chia", () async {
      // Cặp 15k: 10 đực + 10 cái = 10 cặp = 150k (trước đây tính 300k)

      for (final v in [male, female]) {
        await VariantRepository().adjustStock(v.id, 10);
      }

      expect(DashboardService().compute().stockValue, closeTo(150000, 1));
    });

    test(
      "nhập Shopee trùng link combo => cộng kho cả cặp, chỉ đổi giá",
      () async {
        final pair = db.get<ComponentOption>().getAll().firstWhere(
          (o) => o.isCombo,
        )..link = "https://shopee.vn/xt60-i.9.9";
        db.get<ComponentOption>().put(pair);
        final service = ImportService();
        final plans = service.plan(
          ImportService.parse(
            "Tên linh kiện,Phân loại,Giá gói,Số lượng mua,Link\n"
            "Jack XT60 đực cái,1 cặp,16000,3,https://shopee.vn/product/9/9",
          ),
        );
        expect(plans.single.linkedOption?.id, pair.id);
        final result = service.apply(plans, addToStock: true);
        expect(result.stocked, 1);
        expect(result.pricesUpdated, 1);
        final updated = reload(pair.id);
        expect(updated.pricePerPack, 16000);
        expect(updated.unitsPerPack, 1);
        expect(db.get<ComponentVariant>().get(male.id)!.stock, 3);
        expect(db.get<ComponentVariant>().get(female.id)!.stock, 3);
      },
    );
  });
  group("nhập Shopee: đánh dấu combo", () {
    const header =
        "Tên linh kiện,Phân loại,Số cái/gói,Giá gói,Số lượng mua,Shop,Link,Trạng thái,Nguồn\n";

    test("tạo combo mới: linh kiện mới của dòng + module có sẵn", () async {
      final (_, vb) = await createComponent("Module PCF8574");
      final vI2c = vb[""]!;
      final rows = ImportService.parse(
        "$header"
        "Combo LCD1602 + module I2C PCF8574,Xanh,1,60000,2,Shop A,"
        "https://shopee.vn/product/5/5,Hoàn thành,Shopee",
      );
      expect(rows.single.looksLikeCombo, isTrue);
      final service = ImportService();
      final plan = service.plan(rows).single;
      plan
        ..createNew()
        ..name = "LCD 1602"
        ..comboExtras = [ImportComboPart.existing(vI2c)];
      final result = service.apply([plan], addToStock: true);

      final lcd = db.get<Component>().getAll().firstWhere(
        (c) => c.name == "LCD 1602",
      );
      final option = lcd.options.single;
      expect(option.isCombo, isTrue);
      expect(option.unitsPerPack, 1);
      expect(option.pricePerPack, 60000);
      expect(option.unitsFor(vI2c.id), 1);
      expect(option.variants.map((v) => v.id).toSet(), {
        lcd.variants.single.id,
        vI2c.id,
      });
      // Mua 2 combo => +2 LCD, +2 module
      expect(lcd.variants.single.stock, 2);
      expect(db.get<ComponentVariant>().get(vI2c.id)!.stock, 2);

      // Nhập lại cùng link => chỉ cập nhật giá combo
      final again = service.plan(rows).single;
      expect(again.linkedOption?.id, option.id);

      service.undo(result.undo);
      expect(db.get<ComboPart>().count(), 0);
      expect(db.get<ComponentOption>().count(), 0);
      expect(db.get<ComponentVariant>().get(vI2c.id)!.stock, isNull);
    });

    test("cặp XT60: số cái chính theo gói, chưa giao => đang về", () async {
      final (jack, v) = await createComponent(
        "Jack XT60",
        attributes: [
          VariantAttribute("Đầu", ["Đực", "Cái"]),
        ],
        variants: [
          {"Đầu": "Đực"},
          {"Đầu": "Cái"},
        ],
      );
      final rows = ImportService.parse(
        "$header"
        "Jack XT60 đực cái,10 cặp,10,59000,1,Shop B,,Chờ giao hàng,Shopee",
      );
      final service = ImportService();
      final plan = service.plan(rows).single
        ..selectComponent(jack)
        ..variantId = v["Đực"]!.id
        ..comboExtras = [ImportComboPart.existing(v["Cái"]!)];
      // Mặc định số combo / gói = số cái mỗi gói đọc được (10 cặp)
      expect(plan.combosPerPack, 10);
      expect(plan.mainUnits, 10);
      service.apply([plan], addToStock: true);

      final option = db.get<Component>().get(jack.id)!.options.single;
      expect(option.unitsFor(v["Đực"]!.id), 10);
      expect(option.unitsFor(v["Cái"]!.id), 10);
      expect(option.unitPriceFor(v["Cái"]!.id), closeTo(2950, 0.01));
      expect(db.get<ComponentVariant>().get(v["Đực"]!.id)!.incoming, 10);
      expect(db.get<ComponentVariant>().get(v["Cái"]!.id)!.incoming, 10);
    });

    test("5 combo / gói, mỗi combo 1 + 1 => mỗi thành phần 5 cái", () async {
      final (jack, v) = await createComponent(
        "Jack XT60",
        attributes: [
          VariantAttribute("Đầu", ["Đực", "Cái"]),
        ],
        variants: [
          {"Đầu": "Đực"},
          {"Đầu": "Cái"},
        ],
      );
      final rows = ImportService.parse(
        "$header"
        "Jack XT60 đực cái,Combo,1,30000,2,Shop B,,Hoàn thành,Shopee",
      );
      final service = ImportService();
      final plan = service.plan(rows).single
        ..selectComponent(jack)
        ..variantId = v["Đực"]!.id
        ..comboCount = 5
        ..comboUnits = 1
        ..comboExtras = [ImportComboPart.existing(v["Cái"]!)];
      service.apply([plan], addToStock: true);

      final option = db.get<Component>().get(jack.id)!.options.single;
      expect(option.unitsFor(v["Đực"]!.id), 5);
      expect(option.unitsFor(v["Cái"]!.id), 5);
      // Mua 2 gói
      expect(db.get<ComponentVariant>().get(v["Đực"]!.id)!.stock, 10);
      expect(db.get<ComponentVariant>().get(v["Cái"]!.id)!.stock, 10);
    });

    test(
      "linh kiện của dòng không nằm trong combo: không cần biến thể",
      () async {
        final (jack, v) = await createComponent(
          "Jack XT60",
          attributes: [
            VariantAttribute("Đầu", ["Đực", "Cái"]),
          ],
          variants: [
            {"Đầu": "Đực"},
            {"Đầu": "Cái"},
          ],
        );
        final rows = ImportService.parse(
          "$header"
          "Jack XT60 đực cái,10 cặp,10,59000,1,Shop B,,Hoàn thành,Shopee",
        );
        final service = ImportService();
        final plan = service.plan(rows).single..selectComponent(jack);
        // Tên chứa cả "đực" lẫn "cái" => không đoán bừa
        expect(plan.variantId, isNull);
        plan
          ..comboUnits = 0
          ..comboExtras = [
            ImportComboPart.existing(v["Đực"]!),
            ImportComboPart.existing(v["Cái"]!),
          ];
        service.apply([plan], addToStock: true);

        final option = db.get<Component>().get(jack.id)!.options.single;
        expect(option.isCombo, isTrue);
        expect(option.unitsFor(v["Đực"]!.id), 10);
        expect(option.unitsFor(v["Cái"]!.id), 10);
        expect(db.get<ComponentVariant>().get(v["Cái"]!.id)!.stock, 10);
      },
    );

    test(
      "đoán biến thể: khớp một phần, gộp đơn vị, hoà điểm => null",
      () async {
        final (buzzer, _) = await createComponent(
          "Còi chip",
          attributes: [
            VariantAttribute("Điện áp", ["5V", "12V"]),
            VariantAttribute("Kiểu", ["Active", "Passive"]),
          ],
          variants: [
            {"Điện áp": "5V", "Kiểu": "Active"},
            {"Điện áp": "12V", "Kiểu": "Active"},
            {"Điện áp": "5V", "Kiểu": "Passive"},
          ],
        );
        final component = db.get<Component>().get(buzzer.id)!;
        String? match(String text) =>
            BomParser.matchVariant(text, component)?.label;
        expect(match("Còi chip 5V Active"), "5V · Active");
        // Thiếu "Kiểu" nhưng chỉ 1 biến thể 12V
        expect(match("Còi chip 12VDC"), "12V · Active");
        expect(match("Còi chip passive"), "5V · Passive");
        // 5V có 2 biến thể => không đoán
        expect(match("Còi chip 5V"), isNull);
        expect(match("Còi chip"), isNull);
      },
    );

    test("linh kiện mới: combo dùng biến thể mới tạo ngay khi nhập", () {
      final rows = ImportService.parse(
        "$header"
        "Jack XT60 đực cái,10 cặp,10,59000,2,Shop B,,Hoàn thành,Shopee",
      );
      final service = ImportService();
      final plans = service.plan(rows);
      final session = ImportSession(plans);
      final plan = plans.single;
      session.setTarget(plan, null, newName: "Jack XT60");
      session.setVariant(plan, {"Đầu": "Đực"});
      plan.comboExtras = [
        const ImportComboPart.draft(
          newName: "Jack XT60",
          selection: {"Đầu": "Cái"},
        ),
      ];
      // Biến thể "Cái" hiện như biến thể sắp tạo của linh kiện mới
      expect(session.pendingVariants(plan), [
        {"Đầu": "Cái"},
        {"Đầu": "Đực"},
      ]);
      expect(session.comboChoices().map((d) => d.label), [
        "Jack XT60 · Mới: Cái",
        "Jack XT60 · Mới: Đực",
      ]);

      final result = service.apply(plans, addToStock: true);
      expect(result.variantsCreated, 2);
      final jack = db.get<Component>().getAll().single;
      expect(jack.attributes.single.values, ["Cái", "Đực"]);
      final male = jack.variants.firstWhere((v) => v.selection["Đầu"] == "Đực");
      final female = jack.variants.firstWhere(
        (v) => v.selection["Đầu"] == "Cái",
      );
      final option = jack.options.single;
      expect(option.isCombo, isTrue);
      expect(option.unitsFor(female.id), 10);
      expect(male.stock, 20);
      expect(female.stock, 20);

      service.undo(result.undo);
      expect(db.get<Component>().count(), 0);
      expect(db.get<ComponentVariant>().count(), 0);
    });

    test("AI tách combo: khớp nhãn có sẵn, đoán theo tên, báo thiếu", () async {
      final (_, vb) = await createComponent("Module PCF8574");
      final (_, vs) = await createComponent(
        "Ốc M3",
        attributes: [
          VariantAttribute("Loại", ["Lục giác", "Tán"]),
        ],
        variants: [
          {"Loại": "Lục giác"},
          {"Loại": "Tán"},
        ],
      );
      final assistant = ComboAssistant(db.get<ComponentVariant>().getAll());
      expect(ComboAssistant.labelOf(vs["Tán"]!), "Ốc M3 · Tán");
      final prompt = assistant.buildPrompt(
        product: "Combo LCD1602 + PCF8574",
        main: "LCD 1602",
      );
      expect(prompt, contains("- Module PCF8574"));
      expect(prompt, contains("- Ốc M3 · Tán"));

      final s = assistant.parse('''```json
{"isCombo": true, "mainQuantity": "2", "parts": [
  {"item": "module pcf8574", "quantity": 2},
  {"item": "Ốc M3 Tán", "quantity": 4},
  {"item": "Dây cáp 4 sợi", "quantity": 1}
], "note": "ok"}
```''');
      expect(s.isCombo, isTrue);
      expect(s.mainQuantity, 2);
      expect(s.parts.map((p) => (p.variant.id, p.quantity)), [
        (vb[""]!.id, 2),
        (vs["Tán"]!.id, 4),
      ]);
      expect(s.missing.single.name, "Dây cáp 4 sợi");
    });
  });

  group("tìm linh kiện trong ô chọn", () {
    test(
      "đủ các từ trong tên + từ khoá; đoán biến thể theo chuỗi gõ",
      () async {
        final (cap, v) = await createComponent(
          "Tụ hóa",
          attributes: [
            VariantAttribute("Điện dung", ["10uF", "100uF"]),
            VariantAttribute("Điện áp", ["16V", "25V"]),
          ],
          variants: [
            {"Điện dung": "10uF", "Điện áp": "16V"},
            {"Điện dung": "100uF", "Điện áp": "25V"},
            {"Điện dung": "100uF", "Điện áp": "16V"},
          ],
        );
        final search = TextSearch("tu 100uf");
        expect(search.matches(cap.name), isFalse);
        expect(
          search.matchesWords([cap.name, ...ComponentSearch.keywords(cap)]),
          isTrue,
        );
        expect(
          TextSearch("tu 470uf").matchesWords(ComponentSearch.keywords(cap)),
          isFalse,
        );

        expect(
          ComponentSearch.variantFromQuery("tụ 100uF 25v", cap)?.id,
          v["100uF · 25V"]!.id,
        );
        // 2 biến thể 100uF => không đoán
        expect(ComponentSearch.variantFromQuery("tụ 100uF", cap), isNull);
        expect(ComponentSearch.variantFromQuery("tụ", cap), isNull);
      },
    );
  });
}
