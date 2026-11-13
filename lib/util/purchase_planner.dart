import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project_item.dart';

/// 1 phương án mua cho 1 biến thể: các gói (cùng 1 shop) và số lượng mỗi gói.
class PurchasePlan {
  final List<({ComponentOption option, int packs})> parts;

  /// Biến thể cần mua (để biết 1 gói combo có bao nhiêu cái của nó; 0 = theo
  /// [ComponentOption.unitsPerPack]).
  final int variantId;

  /// Combo mua chung cho nhiều dòng: phần tiền tính cho dòng này (null =
  /// trả cả giá gói).
  final int? allocatedCost;

  /// Các linh kiện khác cùng nằm trong combo này (đã tính tiền chung).
  final List<String> sharedWith;

  const PurchasePlan(
    this.parts, {
    this.variantId = 0,
    this.allocatedCost,
    this.sharedWith = const [],
  });

  static const empty = PurchasePlan([]);

  bool get isEmpty => parts.isEmpty;

  /// Toàn bộ tiền các gói (combo chung => cả giá combo).
  int get fullCost =>
      parts.fold(0, (sum, p) => sum + p.packs * p.option.pricePerPack);

  int get cost => allocatedCost ?? fullCost;

  int get units =>
      parts.fold(0, (sum, p) => sum + p.packs * p.option.unitsFor(variantId));

  bool get hasCombo => parts.any((p) => p.option.isCombo);

  int get packCount => parts.fold(0, (sum, p) => sum + p.packs);

  String get shopName => parts.isEmpty ? "" : parts.first.option.shopName;

  /// VD "1 × Gói 10 cái + 2 × Gói 1 cái".
  String get label =>
      parts.map((p) => "${p.packs} × ${p.option.name}").join(" + ");

  /// Số cái nhận được của mọi biến thể (combo => cả các linh kiện đi kèm).
  Map<int, int> get receivedUnits {
    final result = <int, int>{};
    for (final p in parts) {
      if (p.option.isCombo) {
        for (final c in p.option.parts) {
          final id = c.variant.targetId;
          if (id == 0) continue;
          result[id] = (result[id] ?? 0) + p.packs * c.quantity;
        }
      } else if (variantId != 0) {
        result[variantId] =
            (result[variantId] ?? 0) + p.packs * p.option.unitsPerPack;
      }
    }
    return result;
  }
}

/// Chọn cách mua rẻ nhất theo SỐ LƯỢNG CẦN (không chỉ theo đơn giá: cần 3 cái
/// thì mua 3 gói 1 cái có thể rẻ hơn 1 gói 10 cái).
class PurchasePlanner {
  PurchasePlanner._();

  /// Chỉ gợi ý đổi khi rẻ hơn ít nhất tỉ lệ này.
  static const minSaving = 0.01;

  /// Giới hạn bài toán kết hợp gói (số cái) để tính nhanh.
  static const _maxPlanUnits = 100000;

  /// Tiền phải trả để có ít nhất [quantity] cái (của biến thể [variantId])
  /// nếu chỉ mua gói [option]. Combo không có biến thể đó => không mua được.
  static int singleCost(
    ComponentOption option,
    int quantity, {
    int? variantId,
  }) {
    if (quantity <= 0) return 0;
    final raw = option.unitsFor(variantId);
    if (option.isCombo && variantId != null && raw <= 0) return 1 << 40;
    final units = raw <= 0 ? 1 : raw;
    return ((quantity + units - 1) ~/ units) * option.pricePerPack;
  }

  /// Tuỳ chọn áp dụng được cho biến thể.
  static List<ComponentOption> offersFor(ComponentVariant variant) =>
      variant.options.toList();

  /// Tuỳ chọn đơn rẻ nhất cho [quantity] cái. Hoà thì ưu tiên ít dư, rồi đơn giá thấp.
  static ComponentOption? bestSingle(
    Iterable<ComponentOption> offers,
    int quantity, {
    int? variantId,
  }) {
    ComponentOption? best;
    final q = quantity <= 0 ? 1 : quantity;
    int cost(ComponentOption o) => singleCost(o, q, variantId: variantId);
    for (final o in offers) {
      if (best == null) {
        best = o;
        continue;
      }
      final byCost = cost(o).compareTo(cost(best));
      if (byCost < 0) {
        best = o;
      } else if (byCost == 0) {
        final leftover = _leftover(
          o,
          q,
          variantId,
        ).compareTo(_leftover(best, q, variantId));
        if (leftover < 0 ||
            (leftover == 0 &&
                o.unitPriceFor(variantId) < best.unitPriceFor(variantId))) {
          best = o;
        }
      }
    }
    return best;
  }

  static int _leftover(ComponentOption o, int quantity, int? variantId) {
    final raw = o.unitsFor(variantId);
    final units = raw <= 0 ? 1 : raw;
    return ((quantity + units - 1) ~/ units) * units - quantity;
  }

  /// Phương án rẻ nhất để có ít nhất [quantity] cái, được kết hợp nhiều gói
  /// nhưng tất cả trong CÙNG 1 shop (gộp đơn, đỡ phí ship).
  static PurchasePlan bestPlan(
    Iterable<ComponentOption> offers,
    int quantity, {
    String? onlyShop,
    int variantId = 0,
  }) {
    if (quantity <= 0) return PurchasePlan.empty;
    final byShop = <String, List<ComponentOption>>{};
    for (final o in offers) {
      if (onlyShop != null && o.shopName != onlyShop) continue;
      byShop.putIfAbsent(o.shopName, () => []).add(o);
    }

    PurchasePlan? best;
    for (final shopOffers in byShop.values) {
      final plan = _bestPlanInShop(shopOffers, quantity, variantId);
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
    int variantId,
  ) {
    int unitsOf(ComponentOption o) => o.unitsFor(variantId);
    final valid = offers.where((o) => unitsOf(o) > 0).toList();
    if (valid.isEmpty) return PurchasePlan.empty;
    if (quantity > _maxPlanUnits) {
      final single = bestSingle(valid, quantity, variantId: variantId)!;
      final units = unitsOf(single);
      return PurchasePlan([
        (option: single, packs: (quantity + units - 1) ~/ units),
      ], variantId: variantId);
    }

    final maxUnits = valid.map(unitsOf).reduce((a, b) => a > b ? a : b);
    final limit = quantity + maxUnits;
    const inf = 1 << 62;
    final cost = List<int>.filled(limit + 1, inf)..[0] = 0;
    final choice = List<int>.filled(limit + 1, -1);
    for (var u = 1; u <= limit; u++) {
      for (var i = 0; i < valid.length; i++) {
        final prev = u - unitsOf(valid[i]);
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
    for (var u = bestUnits; u > 0; u -= unitsOf(valid[choice[u]])) {
      packs.update(choice[u], (v) => v + 1, ifAbsent: () => 1);
    }
    final parts = [
      for (final e in packs.entries) (option: valid[e.key], packs: e.value),
    ]..sort((a, b) => unitsOf(b.option).compareTo(unitsOf(a.option)));
    return PurchasePlan(parts, variantId: variantId);
  }

  /// Tuỳ chọn rẻ hơn tuỳ chọn đang dùng của [item] cho đúng số lượng cần
  /// (null nếu đang là lựa chọn tốt nhất).
  static ComponentOption? cheaperFor(ProjectItem item) {
    final variant = item.variant.target;
    if (variant == null) return null;
    final best = bestSingle(
      variant.options,
      item.quantity,
      variantId: variant.id,
    );
    final current = item.componentOption.target;
    if (best == null || best.id == current?.id) return null;
    if (current == null) return best;
    final currentCost = singleCost(
      current,
      item.quantity,
      variantId: variant.id,
    );
    if (currentCost <= 0) return null;
    final saving =
        1 -
        singleCost(best, item.quantity, variantId: variant.id) / currentCost;
    return saving >= minSaving ? best : null;
  }

  /// Tỉ lệ tiết kiệm khi đổi sang [cheaper] (0..1).
  static double savingFor(ProjectItem item, ComponentOption cheaper) {
    final current = item.componentOption.target;
    if (current == null) return 0;
    final variantId = item.variant.targetId;
    final currentCost = singleCost(
      current,
      item.quantity,
      variantId: variantId,
    );
    return currentCost <= 0
        ? 0
        : 1 -
              singleCost(cheaper, item.quantity, variantId: variantId) /
                  currentCost;
  }
}
