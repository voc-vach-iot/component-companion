import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component.dart';
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

  ShoppingLine({
    required this.component,
    required this.variant,
    required this.needed,
    required this.plan,
    required this.usedIn,
    required this.subtractStock,
  });

  String get key => "${variant.id}";

  int get inStock => variant.stock ?? 0;

  bool get stockTracked => variant.stock != null;

  String get variantLabel =>
      variant.isDefault ? "" : variant.labelFor(component.attributes);

  int get shortage {
    final missing = needed - (subtractStock ? inStock : 0);
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

class ShoppingList {
  ShoppingList._();

  static const unknownShop = "Chưa ghi shop";

  /// Gộp các linh kiện dự án thành danh sách cần mua.
  ///
  /// [items]: linh kiện kèm nhãn nơi dùng.
  /// [useCheapest]: chọn shop / gói rẻ nhất cho số lượng thiếu; tắt = mua ở
  /// shop của tuỳ chọn đã chọn trong dự án (vẫn tự kết hợp các gói của shop đó).
  static List<ShoppingLine> build(
    Iterable<({ProjectItem item, String usedIn})> items, {
    bool useCheapest = false,
    bool subtractStock = true,
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

    final lines = <ShoppingLine>[];
    for (final g in groups.values) {
      final needed = g.items.fold(0, (sum, e) => sum + e.item.quantity);
      final stock = g.variant.stock ?? 0;
      final shortage = needed - (subtractStock ? stock : 0);
      final offers = g.variant.options.toList();
      final chosenShop = g.items
          .map((e) => e.item.componentOption.target?.shopName)
          .whereType<String>()
          .firstOrNull;

      var plan = PurchasePlan.empty;
      if (shortage > 0) {
        if (!useCheapest && chosenShop != null) {
          plan = PurchasePlanner.bestPlan(
            offers,
            shortage,
            onlyShop: chosenShop,
          );
        }
        if (plan.isEmpty) plan = PurchasePlanner.bestPlan(offers, shortage);
      }

      lines.add(
        ShoppingLine(
          component: g.component,
          variant: g.variant,
          needed: needed,
          plan: plan,
          usedIn: g.items.map((e) => e.usedIn).toSet().toList(),
          subtractStock: subtractStock,
        ),
      );
    }

    return lines..sort((a, b) {
      final byName = a.component.name.toLowerCase().compareTo(
        b.component.name.toLowerCase(),
      );
      return byName != 0 ? byName : a.variantLabel.compareTo(b.variantLabel);
    });
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
          " = ${l.cost.toVND()}",
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
