import 'dart:io';

import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  List<ComponentVariant> variantsOf(int id) =>
      db.get<Component>().get(id)!.sortedVariants;

  test(
    "thêm thuộc tính: biến thể mặc định nhận giá trị đầu, giữ tồn kho",
    () async {
      final repo = ComponentRepository();
      final id = await repo.add(Component(name: "Còi chíp"));
      final variant = variantsOf(id).single..stock = 10;
      db.get<ComponentVariant>().put(variant);

      final component = db.get<Component>().get(id)!
        ..attributes = const [
          VariantAttribute("Điện áp", ["3V", "5V", "12V"]),
        ];
      await repo.update(component);

      final after = variantsOf(id).single;
      expect(after.selection, {"Điện áp": "3V"});
      expect(after.stock, 10);
    },
  );

  test(
    "xoá giá trị thuộc tính: biến thể trùng được gộp, cộng tồn kho",
    () async {
      final repo = ComponentRepository();
      final component = Component(name: "Ốc vít")
        ..attributes = const [
          VariantAttribute("Dài", ["5mm", "8mm"]),
        ];
      final id = await repo.add(component);
      db.get<ComponentVariant>().putMany([
        ComponentVariant(
          selectionJson: Variants.encodeSelection({"Dài": "5mm"}),
          stock: 3,
        )..component.targetId = id,
        ComponentVariant(
          selectionJson: Variants.encodeSelection({"Dài": "8mm"}),
          stock: 4,
        )..component.targetId = id,
      ]);

      final edited = db.get<Component>().get(id)!
        ..attributes = const [
          VariantAttribute("Dài", ["5mm"]),
        ];
      await repo.update(edited);

      final after = variantsOf(id).single;
      expect(after.selection, {"Dài": "5mm"});
      expect(after.stock, 7);
    },
  );
}
