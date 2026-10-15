import 'dart:io';

import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/service/stock_reservation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  /// Kho 10 cái; dự án A đang làm cần 6, dự án B lập kế hoạch cần 8.
  Future<({ComponentVariant variant, int a, int b})> seed() async {
    final (component, variants) = await createComponent("Trở 10K");
    final variant = variants[""]!..stock = 10;
    db.get<ComponentVariant>().put(variant);
    final offer = await addOffer(
      component,
      [variant],
      name: "1 cái",
      units: 1,
      price: 100,
    );
    int project(String name, ProjectStatus status, int qty) {
      final id = db.get<Project>().put(
        Project(name: name, status: status.name),
      );
      db.get<ProjectItem>().put(
        ProjectItem(quantity: qty)
          ..component.targetId = component.id
          ..variant.targetId = variant.id
          ..componentOption.targetId = offer
          ..project.targetId = id,
      );
      return id;
    }

    return (
      variant: variant,
      a: project("A", ProjectStatus.inProgress, 6),
      b: project("B", ProjectStatus.planning, 8),
    );
  }

  test("chỉ dự án đang thực hiện giữ hàng", () async {
    final s = await seed();
    final r = StockReservations.of(db.get<Project>().getAll());
    expect(r.reserved(s.variant.id), 6);
    expect(r.reserved(s.variant.id, except: {s.a}), 0);
    expect(StockReservations.describe(r.holds(s.variant.id)), "A (6)");
  });

  test("cần mua cho B: kho 10 trừ 6 đang giữ cho A => thiếu 4", () async {
    final s = await seed();
    final projects = db.get<Project>().getAll();
    final b = projects.firstWhere((p) => p.id == s.b);
    final reservations = StockReservations.of(projects);

    final kept = ShoppingList.build(
      b.configurationEntries,
      reserved: reservations.totals(except: {s.b}),
    ).single;
    expect((kept.reserved, kept.available, kept.shortage), (6, 4, 4));

    final ignored = ShoppingList.build(b.configurationEntries).single;
    expect(ignored.shortage, 0);
  });

  test("hoàn tác nhập kho trả lại cả trạng thái chưa theo dõi", () async {
    final s = await seed();
    final repo = VariantRepository();
    await repo.adjustStock(s.variant.id, 5);
    await repo.restoreStocks({s.variant.id: null});
    expect(db.get<ComponentVariant>().get(s.variant.id)!.stock, isNull);
  });
}
