import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/util/purchase_planner.dart';

/// 1 dòng cần mua: 1 biến thể linh kiện, gộp từ mọi dự án đã chọn.
class ShoppingLine {
  final Component component;
  final ComponentVariant variant;
  final int needed;

  /// Phương án mua (có thể nhiều gói cùng 1 shop). Rỗng = chưa có tuỳ chọn phù hợp.
  final PurchasePlan plan;

  /// Nơi dùng, VD ["Robot", "Robot · Bản pin"].
  final List<String> usedIn;
  final bool subtractStock;

  /// Số cái trong kho đang giữ cho dự án "Đang thực hiện" khác (không dùng được).
  final int reserved;

  /// Số cái các dự án đã chọn đã lấy khỏi kho (đã trừ khỏi [needed]).
  final int allocated;

  ShoppingLine({
    required this.component,
    required this.variant,
    required this.needed,
    required this.plan,
    required this.usedIn,
    required this.subtractStock,
    this.reserved = 0,
    this.allocated = 0,
  });

  String get key => "${variant.id}";

  int get inStock => variant.stock ?? 0;

  /// Trong kho trừ phần đang giữ cho dự án khác.
  int get available {
    final free = inStock - reserved;
    return free > 0 ? free : 0;
  }

  bool get stockTracked => variant.stock != null;

  /// Đã đặt, chưa nhận.
  int get incoming => variant.incoming;

  String get variantLabel =>
      variant.isDefault ? "" : variant.labelFor(component.attributes);

  int get shortage {
    final missing = needed - (subtractStock ? available + incoming : 0);
    return missing > 0 ? missing : 0;
  }

  bool get isCovered => shortage == 0;

  int get buyUnits => plan.units;

  int get cost => plan.cost;

  String get shop {
    final s = plan.shopName.trim();
    return s.isEmpty ? ShoppingList.unknownShop : s;
  }
}

typedef _Row = ({
  ({
    Component component,
    ComponentVariant variant,
    List<({ProjectItem item, String usedIn})> items,
  })
  group,
  int needed,
  int held,
  int taken,
  int shortage,
  Set<int> chosen,
  String? chosenShop,
});

class ShoppingList {
  ShoppingList._();

  static const unknownShop = "Chưa ghi shop";

  /// Gộp các linh kiện dự án thành danh sách cần mua.
  ///
  /// [items]: linh kiện kèm nhãn nơi dùng.
  /// [useCheapest]: chọn shop / gói rẻ nhất cho số lượng thiếu; tắt = mua ở
  /// shop của tuỳ chọn đã chọn trong dự án (vẫn tự kết hợp các gói của shop đó).
  /// [reserved]: variantId -> số cái trong kho đang giữ cho dự án khác.
  /// [allocated]: variantId -> số cái các dự án này đã lấy khỏi kho (không
  /// cần mua / lấy nữa).
  static List<ShoppingLine> build(
    Iterable<({ProjectItem item, String usedIn})> items, {
    bool useCheapest = false,
    bool subtractStock = true,
    Map<int, int> reserved = const {},
    Map<int, int> allocated = const {},
  }) {
    final groups =
        <
          int,
          ({
            Component component,
            ComponentVariant variant,
            List<({ProjectItem item, String usedIn})> items,
          })
        >{};

    for (final entry in items) {
      final component = entry.item.component.target;
      final variant = entry.item.variant.target;
      // Linh kiện đã bị xoá / chưa chọn biến thể thì bỏ qua
      if (component == null || variant == null) continue;
      groups
          .putIfAbsent(
            variant.id,
            () => (component: component, variant: variant, items: []),
          )
          .items
          .add(entry);
    }

    // 1. Số còn thiếu của từng biến thể
    final rows = [
      for (final g in groups.values)
        () {
          final total = g.items.fold(0, (sum, e) => sum + e.item.quantity);
          final taken = (allocated[g.variant.id] ?? 0).clamp(0, total);
          final needed = total - taken;
          final held = reserved[g.variant.id] ?? 0;
          final stock = (g.variant.stock ?? 0) - held;
          final shortage =
              needed -
              (subtractStock
                  ? (stock > 0 ? stock : 0) + g.variant.incoming
                  : 0);
          return (
            group: g,
            needed: needed,
            held: held,
            taken: taken,
            shortage: shortage,
            chosen: {
              for (final e in g.items)
                if (e.item.componentOption.target case final o?) o.id,
            },
            chosenShop: g.items
                .map((e) => e.item.componentOption.target?.shopName)
                .whereType<String>()
                .firstOrNull,
          );
        }(),
    ];

    // Mua lẻ (không combo), ưu tiên shop đã chọn trong dự án nếu cần
    PurchasePlan single(_Row r) {
      final offers = r.group.variant.options.where((o) => !o.isCombo);
      final variantId = r.group.variant.id;
      var plan = PurchasePlan.empty;
      if (!useCheapest && r.chosenShop != null) {
        plan = PurchasePlanner.bestPlan(
          offers,
          r.shortage,
          onlyShop: r.chosenShop,
          variantId: variantId,
        );
      }
      if (plan.isEmpty) {
        plan = PurchasePlanner.bestPlan(
          offers,
          r.shortage,
          variantId: variantId,
        );
      }
      return plan;
    }

    // 2. Combo: 1 lần mua phủ nhiều dòng, tiền tính 1 lần. Chọn khi rẻ hơn
    // mua lẻ các dòng đó (hoặc dự án đã chọn sẵn combo), combo lợi nhất trước.
    final plans = <int, PurchasePlan>{};
    final singles = <int, PurchasePlan>{};
    PurchasePlan singleOf(_Row r) =>
        singles.putIfAbsent(r.group.variant.id, () => single(r));
    final needing = rows.where((r) => r.shortage > 0).toList();
    final combos = {
      for (final r in needing)
        for (final o in r.group.variant.options)
          if (o.isCombo) o.id: o,
    }.values.toList();
    while (combos.isNotEmpty) {
      ({ComponentOption combo, List<_Row> rows, int packs, double score})? best;
      for (final combo in combos) {
        final covered = [
          for (final r in needing)
            if (!plans.containsKey(r.group.variant.id) &&
                combo.unitsFor(r.group.variant.id) > 0)
              r,
        ];
        if (covered.isEmpty) continue;
        final packs = covered
            .map((r) {
              final q = combo.unitsFor(r.group.variant.id);
              return (r.shortage + q - 1) ~/ q;
            })
            .reduce((a, b) => a > b ? a : b);
        final cost = packs * combo.pricePerPack;
        final forced = covered.any((r) => r.chosen.contains(combo.id));
        // Không mua lẻ được dòng nào => combo là cách duy nhất
        final alternative = covered.fold<double>(0, (sum, r) {
          final plan = singleOf(r);
          return sum + (plan.isEmpty ? double.infinity : plan.cost);
        });
        final saving = alternative - cost;
        // Không mua theo giá rẻ nhất: dòng đã chọn tuỳ chọn khác trong dự án
        // thì giữ lựa chọn đó (trừ khi không mua lẻ được)
        final keepsOther =
            !useCheapest && covered.any((r) => r.chosenShop != null);
        if (!forced && keepsOther && alternative.isFinite) continue;
        if (!forced && saving <= 0) continue;
        final score = forced ? double.infinity : saving;
        if (best == null || score > best.score) {
          best = (combo: combo, rows: covered, packs: packs, score: score);
        }
      }
      if (best == null) break;
      combos.remove(best.combo);

      // Chia tiền combo cho các dòng theo tỉ lệ giá của từng thành phần
      final total = best.packs * best.combo.pricePerPack;
      final shares = [
        for (final r in best.rows) best.combo.priceShare(r.group.variant.id),
      ];
      final shareSum = shares.fold(0.0, (a, b) => a + b);
      var assigned = 0;
      for (var i = 0; i < best.rows.length; i++) {
        final r = best.rows[i];
        final last = i == best.rows.length - 1;
        final part = last
            ? total - assigned
            : (total *
                      (shareSum <= 0
                          ? 1 / best.rows.length
                          : shares[i] / shareSum))
                  .round();
        assigned += part;
        plans[r.group.variant.id] = PurchasePlan(
          [(option: best.combo, packs: best.packs)],
          variantId: r.group.variant.id,
          allocatedCost: part,
          sharedWith: [
            for (final other in best.rows)
              if (!identical(other, r)) other.group.component.name,
          ],
        );
      }
    }

    // 3. Còn lại mua lẻ
    final lines = <ShoppingLine>[
      for (final r in rows)
        ShoppingLine(
          component: r.group.component,
          variant: r.group.variant,
          needed: r.needed,
          plan: r.shortage <= 0
              ? PurchasePlan.empty
              : plans[r.group.variant.id] ?? singleOf(r),
          usedIn: r.group.items.map((e) => e.usedIn).toSet().toList(),
          subtractStock: subtractStock,
          reserved: r.held,
          allocated: r.taken,
        ),
    ];

    return lines..sort((a, b) {
      final byName = a.component.name.toLowerCase().compareTo(
        b.component.name.toLowerCase(),
      );
      return byName != 0 ? byName : a.variantLabel.compareTo(b.variantLabel);
    });
  }

  /// Số cái nhận được khi mua các dòng [lines], theo biến thể. Combo phủ
  /// nhiều dòng chỉ tính 1 lần và cộng cả linh kiện đi kèm (VD mua cặp XT60
  /// khi chỉ cần đầu đực => có cả đầu cái).
  static Map<int, int> receivedUnits(Iterable<ShoppingLine> lines) {
    final result = <int, int>{};
    final combos = <int>{};
    for (final l in lines) {
      final plan = l.plan;
      for (final p in plan.parts) {
        if (p.option.isCombo && !combos.add(p.option.id)) continue;
        final single = PurchasePlan([p], variantId: l.variant.id);
        single.receivedUnits.forEach((id, units) {
          result[id] = (result[id] ?? 0) + units;
        });
      }
    }
    return result;
  }

  /// Các dòng còn thiếu, nhóm theo shop (shop nhiều tiền nhất trước).
  static List<({String shop, List<ShoppingLine> lines, int total})> byShop(
    List<ShoppingLine> lines,
  ) {
    final groups = <String, List<ShoppingLine>>{};
    for (final line in lines.where((l) => !l.isCovered)) {
      groups.putIfAbsent(line.shop, () => []).add(line);
    }
    return [
      for (final e in groups.entries)
        (
          shop: e.key,
          lines: e.value,
          total: e.value.fold(0, (sum, l) => sum + l.cost),
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
  }

  /// Văn bản để dán vào ghi chú / tin nhắn.
  static String toText(List<ShoppingLine> lines) {
    final buffer = StringBuffer();
    var grand = 0;
    for (final group in byShop(lines)) {
      buffer.writeln("🛒 ${group.shop} — ${group.total.toVND()}");
      for (final l in group.lines) {
        final variant = l.variantLabel.isEmpty ? "" : " (${l.variantLabel})";
        buffer.writeln(
          "  • ${l.component.name}$variant: "
          "${l.plan.isEmpty ? "chưa có tùy chọn mua" : l.plan.label}"
          " = ${l.cost.toVND()}"
          "${l.plan.hasCombo ? " (combo: ${l.plan.parts.where((p) => p.option.isCombo).map((p) => p.option.contentsLabel).join(", ")}"
                    "${l.plan.sharedWith.isEmpty ? "" : "; tiền chia với ${l.plan.sharedWith.join(", ")}"})" : ""}",
        );
        for (final part in l.plan.parts) {
          if (part.option.link.isNotEmpty) {
            buffer.writeln("    ${part.option.link}");
          }
        }
      }
      buffer.writeln();
      grand += group.total;
    }
    buffer.writeln("Tổng cộng: ${grand.toVND()}");
    return buffer.toString();
  }

  /// CSV (dấu phẩy, có ngoặc kép) để mở bằng Excel / Google Sheets.
  static String toCsv(List<ShoppingLine> lines) {
    final rows = <List<Object?>>[
      [
        "Shop",
        "Linh kiện",
        "Biến thể",
        "Cần",
        "Tồn kho",
        "Đang về",
        "Thiếu",
        "Mua",
        "Thành tiền",
        "Link",
        "Dùng cho",
      ],
      for (final group in byShop(lines))
        for (final l in group.lines)
          [
            group.shop,
            l.component.name,
            l.variantLabel,
            l.needed,
            l.stockTracked ? l.inStock : "",
            l.incoming > 0 ? l.incoming : "",
            l.shortage,
            l.plan.label,
            l.cost,
            l.plan.parts
                .map((p) => p.option.link)
                .where((link) => link.isNotEmpty)
                .join(" "),
            l.usedIn.join("; "),
          ],
    ];
    return Csv.encode(rows);
  }
}

/// Mã hoá / giải mã CSV đơn giản (RFC 4180).
class Csv {
  Csv._();

  static String encode(List<List<Object?>> rows) => rows
      .map((row) => row.map((cell) => _escape("${cell ?? ""}")).join(","))
      .join("\r\n");

  static String _escape(String value) => value.contains(RegExp(r'[",\r\n]'))
      ? '"${value.replaceAll('"', '""')}"'
      : value;

  /// Đọc CSV; tự nhận dấu phân cách ',' ';' hoặc tab theo dòng đầu.
  static List<List<String>> decode(String text) {
    final firstLine = text.split(RegExp(r'\r?\n')).first;
    final delimiter = [",", ";", "\t"].reduce(
      (a, b) => firstLine.split(a).length >= firstLine.split(b).length ? a : b,
    );

    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == delimiter) {
        row.add(cell.toString());
        cell.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
        row = [];
      } else {
        cell.write(ch);
      }
    }
    row.add(cell.toString());
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    return rows;
  }
}
