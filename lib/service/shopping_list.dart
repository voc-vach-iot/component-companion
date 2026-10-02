import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/util/price_advisor.dart';

/// 1 dòng cần mua: 1 linh kiện + 1 biến thể, gộp từ mọi dự án đã chọn.
class ShoppingLine {
  final Component component;
  final VariantSelection variant;
  final int needed;
  final int inStock;
  final bool stockTracked;
  final ComponentOption? option;

  /// Nơi dùng, VD ["Robot (cơ bản)", "Robot · Bản pin"].
  final List<String> usedIn;
  final bool subtractStock;

  ShoppingLine({
    required this.component,
    required this.variant,
    required this.needed,
    required this.inStock,
    required this.stockTracked,
    required this.option,
    required this.usedIn,
    required this.subtractStock,
  });

  String get key => "${component.id}|${Variants.key(variant)}";

  String get variantLabel => Variants.label(variant, component.attributes);

  int get shortage {
    final missing = needed - (subtractStock ? inStock : 0);
    return missing > 0 ? missing : 0;
  }

  bool get isCovered => shortage == 0;

  /// Số gói phải mua theo tuỳ chọn đã chọn.
  int get packs {
    final o = option;
    if (o == null || shortage == 0) return 0;
    final units = o.unitsPerPack <= 0 ? 1 : o.unitsPerPack;
    return (shortage + units - 1) ~/ units;
  }

  int get buyUnits => packs * (option?.unitsPerPack ?? 0);

  int get cost => packs * (option?.pricePerPack ?? 0);

  String get shop {
    final s = option?.shop.trim() ?? "";
    return s.isEmpty ? ShoppingList.unknownShop : s;
  }
}

class ShoppingList {
  ShoppingList._();

  static const unknownShop = "Chưa ghi shop";

  /// Gộp các linh kiện dự án thành danh sách cần mua.
  ///
  /// [items]: linh kiện kèm nhãn nơi dùng.
  /// [useCheapest]: mua ở tuỳ chọn rẻ nhất thay vì tuỳ chọn đã chọn trong dự án.
  static List<ShoppingLine> build(
    Iterable<({ProjectItem item, String usedIn})> items, {
    bool useCheapest = false,
    bool subtractStock = true,
  }) {
    final groups =
        <
          String,
          ({
            Component component,
            VariantSelection variant,
            List<({ProjectItem item, String usedIn})> items,
          })
        >{};

    for (final entry in items) {
      final component = entry.item.component.target;
      if (component == null) continue; // linh kiện đã bị xoá
      final variant = Variants.sanitizeSelection(
        entry.item.variant,
        component.attributes,
      );
      final key = "${component.id}|${Variants.key(variant)}";
      groups
          .putIfAbsent(
            key,
            () => (component: component, variant: variant, items: []),
          )
          .items
          .add(entry);
    }

    return [
      for (final g in groups.values)
        ShoppingLine(
          component: g.component,
          variant: g.variant,
          needed: g.items.fold(0, (sum, e) => sum + e.item.quantity),
          inStock: g.component.stockOf(g.variant),
          stockTracked: g.component.stockItems.isNotEmpty,
          option: useCheapest
              ? PriceAdvisor.cheapest(g.component, g.variant)
              : g.items
                        .map((e) => e.item.componentOption.target)
                        .whereType<ComponentOption>()
                        .firstOrNull ??
                    PriceAdvisor.cheapest(g.component, g.variant),
          usedIn: g.items.map((e) => e.usedIn).toSet().toList(),
          subtractStock: subtractStock,
        ),
    ]..sort(
      (a, b) => a.component.name.toLowerCase().compareTo(
        b.component.name.toLowerCase(),
      ),
    );
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
          "  • ${l.component.name}$variant: ${l.packs} x ${l.option?.name ?? "?"}"
          " = ${l.cost.toVND()}",
        );
        if (l.option?.link.isNotEmpty == true) {
          buffer.writeln("    ${l.option!.link}");
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
        "Tùy chọn",
        "Số gói",
        "Giá/gói",
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
            l.option?.name ?? "",
            l.packs,
            l.option?.pricePerPack ?? "",
            l.cost,
            l.option?.link ?? "",
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
