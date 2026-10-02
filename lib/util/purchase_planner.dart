import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project_item.dart';

/// 1 phương án mua: các gói (cùng 1 shop) và số lượng mỗi gói.
class PurchasePlan {
  final List<({ComponentOption option, int packs})> parts;

  const PurchasePlan(this.parts);

  static const empty = PurchasePlan([]);

  bool get isEmpty => parts.isEmpty;

  int get cost =>
      parts.fold(0, (sum, p) => sum + p.packs * p.option.pricePerPack);

  int get units =>
      parts.fold(0, (sum, p) => sum + p.packs * p.option.unitsPerPack);

  int get packCount => parts.fold(0, (sum, p) => sum + p.packs);

  String get shopName => parts.isEmpty ? "" : parts.first.option.shopName;

  /// VD "1 × Gói 10 cái + 2 × Gói 1 cái".
  String get label =>
      parts.map((p) => "${p.packs} × ${p.option.name}").join(" + ");
}

/// Chọn cách mua rẻ nhất theo SỐ LƯỢNG CẦN (không chỉ theo đơn giá: cần 3 cái
/// thì mua 3 gói 1 cái có thể rẻ hơn 1 gói 10 cái).
class PurchasePlanner {
  PurchasePlanner._();

  /// Chỉ gợi ý đổi khi rẻ hơn ít nhất tỉ lệ này.
  static const minSaving = 0.01;

  /// Giới hạn bài toán kết hợp gói (số cái) để tính nhanh.
  static const _maxPlanUnits = 20000;

  /// Tiền phải trả để có ít nhất [quantity] cái nếu chỉ mua gói [option].
  static int singleCost(ComponentOption option, int quantity) {
    if (quantity <= 0) return 0;
    final units = option.unitsPerPack <= 0 ? 1 : option.unitsPerPack;
    return ((quantity + units - 1) ~/ units) * option.pricePerPack;
  }

  /// Tuỳ chọn áp dụng được cho biến thể.
  static List<ComponentOption> offersFor(ComponentVariant variant) =>
      variant.options.toList();

  /// Tuỳ chọn đơn rẻ nhất cho [quantity] cái. Hoà thì ưu tiên ít dư, rồi đơn giá thấp.
  static ComponentOption? bestSingle(
    Iterable<ComponentOption> offers,
    int quantity,
  ) {
    ComponentOption? best;
    for (final o in offers) {
      if (best == null) {
        best = o;
        continue;
      }
      final q = quantity <= 0 ? 1 : quantity;
      final byCost = singleCost(o, q).compareTo(singleCost(best, q));
      if (byCost < 0) {
        best = o;
      } else if (byCost == 0) {
        final leftover = _leftover(o, q).compareTo(_leftover(best, q));
        if (leftover < 0 ||
            (leftover == 0 && o.pricePerUnit < best.pricePerUnit)) {
          best = o;
        }
      }
    }
    return best;
  }

  static int _leftover(ComponentOption o, int quantity) {
    final units = o.unitsPerPack <= 0 ? 1 : o.unitsPerPack;
    return ((quantity + units - 1) ~/ units) * units - quantity;
  }

  /// Phương án rẻ nhất để có ít nhất [quantity] cái, được kết hợp nhiều gói
  /// nhưng tất cả trong CÙNG 1 shop (gộp đơn, đỡ phí ship).
  static PurchasePlan bestPlan(
    Iterable<ComponentOption> offers,
    int quantity, {
    String? onlyShop,
  }) {
    if (quantity <= 0) return PurchasePlan.empty;
    final byShop = <String, List<ComponentOption>>{};
    for (final o in offers) {
      if (onlyShop != null && o.shopName != onlyShop) continue;
      byShop.putIfAbsent(o.shopName, () => []).add(o);
    }

    PurchasePlan? best;
    for (final shopOffers in byShop.values) {
      final plan = _bestPlanInShop(shopOffers, quantity);
      if (plan.isEmpty) continue;
      if (best == null ||
          plan.cost < best.cost ||
          (plan.cost == best.cost && plan.units < best.units)) {
        best = plan;
      }
    }
    return best ?? PurchasePlan.empty;
  }

  /// Bài toán "đồng xu" không giới hạn: chi phí nhỏ nhất để đạt >= quantity cái.
  static PurchasePlan _bestPlanInShop(
    List<ComponentOption> offers,
    int quantity,
  ) {
    final valid = offers.where((o) => o.unitsPerPack > 0).toList();
    if (valid.isEmpty) return PurchasePlan.empty;
    if (quantity > _maxPlanUnits) {
      final single = bestSingle(valid, quantity)!;
      final units = single.unitsPerPack;
      return PurchasePlan([
        (option: single, packs: (quantity + units - 1) ~/ units),
      ]);
    }

    final maxUnits = valid
        .map((o) => o.unitsPerPack)
        .reduce((a, b) => a > b ? a : b);
    final limit = quantity + maxUnits;
    const inf = 1 << 62;
    final cost = List<int>.filled(limit + 1, inf)..[0] = 0;
    final choice = List<int>.filled(limit + 1, -1);
    for (var u = 1; u <= limit; u++) {
      for (var i = 0; i < valid.length; i++) {
        final prev = u - valid[i].unitsPerPack;
        if (prev < 0 || cost[prev] == inf) continue;
        final c = cost[prev] + valid[i].pricePerPack;
        if (c < cost[u]) {
          cost[u] = c;
          choice[u] = i;
        }
      }
    }

    // Số cái >= quantity có chi phí thấp nhất (hoà thì lấy ít dư hơn)
    var bestUnits = -1;
    for (var u = quantity; u <= limit; u++) {
      if (cost[u] == inf) continue;
      if (bestUnits < 0 || cost[u] < cost[bestUnits]) bestUnits = u;
    }
    if (bestUnits < 0) return PurchasePlan.empty;

    final packs = <int, int>{};
    for (var u = bestUnits; u > 0; u -= valid[choice[u]].unitsPerPack) {
      packs.update(choice[u], (v) => v + 1, ifAbsent: () => 1);
    }
    final parts = [
      for (final e in packs.entries) (option: valid[e.key], packs: e.value),
    ]..sort((a, b) => b.option.unitsPerPack.compareTo(a.option.unitsPerPack));
    return PurchasePlan(parts);
  }

  /// Tuỳ chọn rẻ hơn tuỳ chọn đang dùng của [item] cho đúng số lượng cần
  /// (null nếu đang là lựa chọn tốt nhất).
  static ComponentOption? cheaperFor(ProjectItem item) {
    final variant = item.variant.target;
    if (variant == null) return null;
    final best = bestSingle(variant.options, item.quantity);
    final current = item.componentOption.target;
    if (best == null || best.id == current?.id) return null;
    if (current == null) return best;
    final currentCost = singleCost(current, item.quantity);
    if (currentCost <= 0) return null;
    final saving = 1 - singleCost(best, item.quantity) / currentCost;
    return saving >= minSaving ? best : null;
  }

  /// Tỉ lệ tiết kiệm khi đổi sang [cheaper] (0..1).
  static double savingFor(ProjectItem item, ComponentOption cheaper) {
    final current = item.componentOption.target;
    if (current == null) return 0;
    final currentCost = singleCost(current, item.quantity);
    return currentCost <= 0
        ? 0
        : 1 - singleCost(cheaper, item.quantity) / currentCost;
  }
}
