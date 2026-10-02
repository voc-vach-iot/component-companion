import 'package:component_companion/model/search_params/search_options.dart';

/// Bộ so khớp chuỗi dùng chung cho mọi ô tìm kiếm (danh sách + dropdown).
///
/// So khớp trên chuỗi đã chuẩn hóa (bỏ dấu, hạ chữ thường tùy chọn) nhưng
/// vùng highlight trả về theo vị trí trong chuỗi GỐC.
class TextSearch {
  final String query;
  final SearchOptions options;

  late final bool caseSensitive = switch (options.caseMode) {
    SearchCaseMode.sensitive => true,
    SearchCaseMode.insensitive => false,
    // Smart case: có ít nhất 1 chữ hoa => phân biệt hoa thường
    SearchCaseMode.smart => query.runes.any((r) {
      final c = String.fromCharCode(r);
      return c != c.toLowerCase();
    }),
  };

  late final String _query = _normalize(query.trim()).text;
  late final List<String> _tokens = _query
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  TextSearch(this.query, [this.options = const SearchOptions()]);

  bool get isEmpty => _query.isEmpty;

  /// Chuỗi tìm sau khi chuẩn hoá (bỏ dấu / hạ chữ thường theo tuỳ chọn).
  String get normalizedQuery => _query;

  /// Có khớp hay không (chuỗi tìm rỗng => luôn khớp).
  bool matches(String text) => isEmpty || _findRanges(text) != null;

  /// Lọc danh sách, giữ nguyên thứ tự.
  List<T> filter<T>(Iterable<T> items, String Function(T item) textOf) =>
      isEmpty
      ? items.toList()
      : items.where((i) => matches(textOf(i))).toList();

  /// Lọc và xếp hạng: ít đoạn khớp rời rạc hơn và khớp sớm hơn đứng trước
  /// (VD chế độ "tất cả ký tự": 'tuhoa' => "Tụ hóa" trước "Mắt thu hồng ngoại").
  /// Thứ tự gốc được giữ khi điểm bằng nhau.
  List<T> rank<T>(Iterable<T> items, String Function(T item) textOf) {
    if (isEmpty) return items.toList();
    final scored = <(T, int, int, int)>[];
    var order = 0;
    for (final item in items) {
      final ranges = _findRanges(textOf(item));
      if (ranges == null) continue;
      scored.add((item, ranges.length, ranges.first.$1, order++));
    }
    scored.sort((a, b) {
      if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
      if (a.$3 != b.$3) return a.$3.compareTo(b.$3);
      return a.$4.compareTo(b.$4);
    });
    return [for (final s in scored) s.$1];
  }

  /// Các vùng cần highlight trong [text] gốc (đã gộp, sắp xếp). Rỗng nếu không khớp.
  List<(int, int)> highlights(String text) =>
      isEmpty ? const [] : (_findRanges(text) ?? const []);

  // ---------------------------------------------------------------------------

  List<(int, int)>? _findRanges(String text) {
    final normalized = _normalize(text);
    final n = normalized.text;
    final List<(int, int)>? ranges = switch (options.matchMode) {
      SearchMatchMode.contains => _allOccurrences(n, _query),
      SearchMatchMode.startsWith =>
        n.startsWith(_query) ? [(0, _query.length)] : null,
      SearchMatchMode.wholeWord => _allOccurrences(n, _query, wholeWord: true),
      SearchMatchMode.allWords => _allWords(n),
      SearchMatchMode.allChars => _subsequence(n),
    };
    if (ranges == null) return null;
    return _merge(ranges.map((r) => normalized.toOriginal(text, r)).toList());
  }

  List<(int, int)>? _allOccurrences(
    String n,
    String q, {
    bool wholeWord = false,
  }) {
    if (q.isEmpty) return null;
    final result = <(int, int)>[];
    var start = n.indexOf(q);
    while (start >= 0) {
      final end = start + q.length;
      if (!wholeWord || (_isBoundary(n, start - 1) && _isBoundary(n, end))) {
        result.add((start, end));
      }
      start = n.indexOf(q, start + 1);
    }
    return result.isEmpty ? null : result;
  }

  List<(int, int)>? _allWords(String n) {
    final result = <(int, int)>[];
    for (final token in _tokens) {
      final found = _allOccurrences(n, token);
      if (found == null) return null;
      result.addAll(found);
    }
    return result;
  }

  /// Khớp ký tự theo thứ tự. Chọn cửa sổ khớp NGẮN NHẤT (quét xuôi tìm điểm
  /// kết thúc, quét ngược để kéo điểm bắt đầu về sát nhất) để highlight gọn,
  /// VD 'sao9' trong "Servo (bản sao 9)" tô "sao 9" thay vì chữ S của Servo.
  List<(int, int)>? _subsequence(String n) {
    final chars = _query.replaceAll(RegExp(r'\s+'), '').split('');
    if (chars.isEmpty) return null;

    List<int>? best;
    var from = 0;
    while (true) {
      // Quét xuôi: vị trí kết thúc sớm nhất bắt đầu từ [from]
      var end = from - 1;
      for (final c in chars) {
        end = n.indexOf(c, end + 1);
        if (end < 0) break;
      }
      if (end < 0) break;

      // Quét ngược từ điểm kết thúc để có điểm bắt đầu muộn nhất
      final positions = List<int>.filled(chars.length, 0);
      var back = end;
      for (var k = chars.length - 1; k >= 0; k--) {
        back = n.lastIndexOf(chars[k], back);
        positions[k] = back;
        back--;
      }
      if (best == null ||
          positions.last - positions.first < best.last - best.first) {
        best = positions;
      }
      from = positions.first + 1;
    }

    return best?.map((i) => (i, i + 1)).toList();
  }

  static final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

  bool _isBoundary(String n, int index) =>
      index < 0 || index >= n.length || !_wordChar.hasMatch(n[index]);

  static List<(int, int)> _merge(List<(int, int)> ranges) {
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final r in ranges) {
      if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
        final last = merged.removeLast();
        merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
      } else {
        merged.add(r);
      }
    }
    return merged;
  }

  _Normalized _normalize(String input) {
    final out = StringBuffer();
    final origin = <int>[];
    for (var i = 0; i < input.length; i++) {
      var unit = input[i];
      if (options.normalize) {
        if (_isCombiningMark(unit.codeUnitAt(0))) continue;
        unit = _foldMap[unit] ?? unit;
      }
      if (!caseSensitive) unit = unit.toLowerCase();
      out.write(unit);
      for (var k = 0; k < unit.length; k++) {
        origin.add(i);
      }
    }
    return _Normalized(out.toString(), origin);
  }

  static bool _isCombiningMark(int code) => code >= 0x0300 && code <= 0x036F;

  static final Map<String, String> _foldMap = () {
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵäåā',
      'A': 'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÄÅĀ',
      'e': 'èéẹẻẽêềếệểễëē',
      'E': 'ÈÉẸẺẼÊỀẾỆỂỄËĒ',
      'i': 'ìíịỉĩïī',
      'I': 'ÌÍỊỈĨÏĪ',
      'o': 'òóọỏõôồốộổỗơờớợởỡöøō',
      'O': 'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÖØŌ',
      'u': 'ùúụủũưừứựửữüūµμ',
      'U': 'ÙÚỤỦŨƯỪỨỰỬỮÜŪ',
      'y': 'ỳýỵỷỹÿ',
      'Y': 'ỲÝỴỶỸ',
      'd': 'đ',
      'D': 'Đ',
      'c': 'ç',
      'C': 'Ç',
      'n': 'ñ',
      'N': 'Ñ',
    };
    final map = <String, String>{
      for (final entry in groups.entries)
        for (final ch in entry.value.split('')) ch: entry.key,
    };
    // Ký hiệu hay gặp trong tên linh kiện
    map['Ω'] = 'ohm';
    map['Ω'] = 'ohm';
    return map;
  }();
}

class _Normalized {
  final String text;

  /// origin[i] = vị trí trong chuỗi gốc sinh ra ký tự text[i].
  final List<int> origin;

  _Normalized(this.text, this.origin);

  (int, int) toOriginal(String original, (int, int) range) {
    final start = origin[range.$1];
    var end = origin[range.$2 - 1] + 1;
    // Kéo theo các dấu tổ hợp (NFD) đi sau ký tự cuối
    while (end < original.length &&
        TextSearch._isCombiningMark(original.codeUnitAt(end))) {
      end++;
    }
    return (start, end);
  }
}
