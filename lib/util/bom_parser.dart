import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/util/text_search.dart';

/// 1 dòng BOM đã đọc: mô tả linh kiện + số lượng.
typedef BomLine = ({String text, int quantity});

/// Đọc BOM dán từ text / bảng tính và đoán linh kiện, biến thể có sẵn.
///
/// Mỗi dòng 1 linh kiện, số lượng ở đầu hoặc cuối: "5x LM358", "LM358 x5",
/// "10 Điện trở 10K", "Tụ 100nF: 4", "LED đỏ (3)". Dòng nhiều cột (tab, `;`,
/// `,` — VD copy từ Excel / BOM KiCad) => cột số đầu tiên là số lượng, các cột
/// chữ còn lại ghép thành mô tả.
class BomParser {
  BomParser._();

  static final _leadingQty = RegExp(
    r'^(\d+)\s*(?:[x×*]|pcs|cái|chiếc)?\s+(.+)$',
    caseSensitive: false,
  );
  // Dấu x / - cần khoảng trắng phía trước để không cắt nhầm "ESP-01", "0x10"
  static final _trailingQty = RegExp(
    r'^(.+?)(?:\s+[x×*]\s*|\s*[:=]\s*|\s+[-–]\s+|\s*\(\s*)(\d+)\s*(?:pcs|cái|chiếc)?\s*\)?$',
    caseSensitive: false,
  );
  static final _number = RegExp(r'^\d+$');

  static List<BomLine> parse(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final result = <BomLine>[];
    for (final line in lines) {
      final parsed = line.contains(RegExp(r'[\t;]')) || _isCsvRow(line)
          ? _parseCells(Csv.decode(line).firstOrNull ?? [line])
          : _parsePlain(line);
      if (parsed != null) result.add(parsed);
    }
    // Dòng tiêu đề bảng (VD "Tên, Số lượng") không có số => bỏ nếu là dòng đầu
    if (result.isNotEmpty &&
        lines.first.contains(RegExp(r'[\t;,]')) &&
        !lines.first.contains(RegExp(r'\d'))) {
      result.removeAt(0);
    }
    return result;
  }

  /// "R1,10K,R_0805,1" — có dấu phẩy và ít nhất 1 ô là số nguyên.
  static bool _isCsvRow(String line) =>
      line.contains(",") &&
      line.split(",").any((c) => _number.hasMatch(c.trim()));

  static BomLine? _parseCells(List<String> cells) {
    int? quantity;
    final words = <String>[];
    for (final raw in cells) {
      final cell = raw.trim();
      if (cell.isEmpty) continue;
      if (quantity == null && _number.hasMatch(cell)) {
        quantity = int.parse(cell);
      } else {
        words.add(cell);
      }
    }
    if (words.isEmpty) return null;
    return (text: words.join(" "), quantity: quantity ?? 1);
  }

  static BomLine? _parsePlain(String line) {
    final lead = _leadingQty.firstMatch(line);
    if (lead != null) {
      return (text: lead.group(2)!.trim(), quantity: int.parse(lead.group(1)!));
    }
    final trail = _trailingQty.firstMatch(line);
    if (trail != null) {
      return (
        text: trail.group(1)!.trim(),
        quantity: int.parse(trail.group(2)!),
      );
    }
    return (text: line, quantity: 1);
  }

  static String _norm(String s) => TextSearch(
    s,
    const SearchOptions(caseMode: SearchCaseMode.insensitive),
  ).normalizedQuery;

  static Set<String> _tokens(String s) =>
      _norm(s).split(RegExp(r'[^a-z0-9.]+')).where((t) => t.isNotEmpty).toSet();

  /// Linh kiện khớp nhất với mô tả (null nếu không đủ giống).
  ///
  /// Điểm = tỉ lệ từ trong tên linh kiện xuất hiện trong mô tả, cộng thêm khi
  /// mô tả chứa nguyên tên. Cần >= 1 nửa số từ của tên.
  static Component? matchComponent(
    String text,
    Iterable<Component> components,
  ) {
    final line = _tokens(text);
    final normalized = _norm(text);
    Component? best;
    var bestScore = 0.0;
    for (final c in components) {
      final name = _tokens(c.name);
      if (name.isEmpty) continue;
      final hit = name.where(line.contains).length;
      var score = hit / name.length;
      if (normalized.contains(_norm(c.name))) score += 1;
      // Tên ngắn gọn hơn được ưu tiên khi bằng điểm (ít từ thừa)
      score += hit / (name.length + 20);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return bestScore >= 0.5 ? best : null;
  }

  /// Biến thể có mọi giá trị thuộc tính xuất hiện trong mô tả (khớp nhiều giá
  /// trị nhất). Linh kiện không thuộc tính => biến thể mặc định.
  static ComponentVariant? matchVariant(String text, Component component) {
    final variants = component.sortedVariants;
    if (!component.hasVariants) return variants.firstOrNull;
    final line = _tokens(text);
    ComponentVariant? best;
    var bestHits = 0;
    for (final v in variants) {
      final values = v.selection.values.map(_tokens).toList();
      if (values.isEmpty) continue;
      if (!values.every((value) => value.every(line.contains))) continue;
      final hits = values.fold(0, (s, value) => s + value.length);
      if (hits > bestHits) {
        bestHits = hits;
        best = v;
      }
    }
    return best;
  }
}
