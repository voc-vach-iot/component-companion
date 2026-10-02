import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/data/shop_repository.dart';
import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/objectbox_service.dart';

/// Tạo linh kiện + biến thể nhanh cho test.
Future<(Component, Map<String, ComponentVariant>)> createComponent(
  String name, {
  List<VariantAttribute> attributes = const [],
  List<VariantSelection> variants = const [],
}) async {
  final db = ObjectboxService.instance;
  final id = await ComponentRepository().add(
    Component(name: name)..attributes = attributes,
  );
  if (variants.isNotEmpty) await VariantRepository().addMany(id, variants);
  final component = db.get<Component>().get(id)!;
  return (
    component,
    {
      for (final v in component.variants)
        v.isDefault ? "" : Variants.label(v.selection, attributes): v,
    },
  );
}

/// Thêm tuỳ chọn mua cho các biến thể.
Future<int> addOffer(
  Component component,
  List<ComponentVariant> variants, {
  required String name,
  required int units,
  required int price,
  String shop = "",
}) {
  final option = ComponentOption(
    name: name,
    unitsPerPack: units,
    pricePerPack: price,
  )..component.targetId = component.id;
  if (shop.isNotEmpty) option.shop.target = ShopRepository().findOrCreate(shop);
  option.variants.addAll(variants);
  return ComponentOptionRepository().add(option);
}
