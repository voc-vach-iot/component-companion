import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/util/price_insight.dart';

class DashboardData {
  final int componentCount;
  final int trackedCount;
  final double stockValue;

  /// Biến thể hết / sắp hết hàng.
  final List<ComponentVariant> lowStock;
  final List<PriceInsight> stalePrices;
  final List<PriceInsight> priceIncreases;
  final List<({Project project, double cost, int toBuy})> projects;
  final List<({String name, int color, double value})> valueByCategory;

  DashboardData({
    required this.componentCount,
    required this.trackedCount,
    required this.stockValue,
    required this.lowStock,
    required this.stalePrices,
    required this.priceIncreases,
    required this.projects,
    required this.valueByCategory,
  });
}

class DashboardService {
  /// Giá tăng từ mức này trở lên thì đưa vào cảnh báo.
  static const bigIncrease = 0.3;

  final _db = ObjectboxService.instance;

  Stream<DashboardData> watch() => _db
      .watchTables([
        _db.store.watch<Component>(),
        _db.store.watch<ComponentOption>(),
        _db.store.watch<PriceRecord>(),
        _db.store.watch<ComponentVariant>(),
        _db.store.watch<Shop>(),
        _db.store.watch<Category>(),
        _db.store.watch<Project>(),
        _db.store.watch<ProjectOption>(),
        _db.store.watch<ProjectItem>(),
      ])
      .map((_) => compute());

  DashboardData compute() {
    final components = _db.get<Component>().getAll();

    // Giá trị kho: mỗi biến thể tính theo đơn giá rẻ nhất của nó
    var stockValue = 0.0;
    final valueByCategory = <int, double>{};
    final lowStock = <ComponentVariant>[];
    for (final c in components) {
      var value = 0.0;
      for (final v in c.variants) {
        if (v.isOut || v.isLow) lowStock.add(v);
        final stock = v.stock ?? 0;
        if (stock == 0 || v.options.isEmpty) continue;
        final cheapest = v.options
            .map((o) => o.pricePerUnit)
            .reduce((a, b) => a < b ? a : b);
        value += stock * cheapest;
      }
      stockValue += value;
      if (value > 0) {
        valueByCategory.update(
          c.category.targetId,
          (v) => v + value,
          ifAbsent: () => value,
        );
      }
    }
    lowStock.sort((a, b) => (a.stock ?? 0).compareTo(b.stock ?? 0));

    final insights = [
      for (final o in _db.get<ComponentOption>().getAll()) PriceInsight.of(o),
    ];
    final stale = insights.where((i) => i.isStale).toList()
      ..sort((a, b) => a.checkedAt!.compareTo(b.checkedAt!));
    final increases =
        insights
            .where((i) => i.trend != null && i.trend! >= bigIncrease)
            .toList()
          ..sort((a, b) => b.trend!.compareTo(a.trend!));

    final projects = [
      for (final p in _db.get<Project>().getAll())
        if (p.projectStatus != ProjectStatus.archived)
          () {
            final lines = ShoppingList.build([
              for (final item in p.baseItems) (item: item, usedIn: p.name),
            ]);
            return (
              project: p,
              cost: p.baseItems.fold<double>(0, (sum, i) => sum + i.totalPrice),
              toBuy: lines.fold<int>(0, (sum, l) => sum + l.cost),
            );
          }(),
    ]..sort((a, b) => b.project.updatedAt.compareTo(a.project.updatedAt));

    final categories = {for (final c in _db.get<Category>().getAll()) c.id: c};
    final byCategory = [
      for (final e in valueByCategory.entries)
        (
          name: categories[e.key]?.name ?? "Chưa phân loại",
          color: categories[e.key]?.colorValue ?? 0xFFE2E2E2,
          value: e.value,
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));

    return DashboardData(
      componentCount: components.length,
      trackedCount: components.where((c) => c.stockTotal != null).length,
      stockValue: stockValue,
      lowStock: lowStock,
      stalePrices: stale,
      priceIncreases: increases,
      projects: projects,
      valueByCategory: byCategory,
    );
  }
}
