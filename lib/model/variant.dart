import 'dart:convert';

/// Một thuộc tính biến thể của linh kiện, VD: "Màu" = [Đỏ, Xanh],
/// "Chiều dài" = [5mm, 8mm, 10mm].
class VariantAttribute {
  final String name;
  final List<String> values;

  const VariantAttribute(this.name, this.values);

  Map<String, dynamic> toJson() => {"name": name, "values": values};

  static VariantAttribute fromJson(Map<String, dynamic> json) =>
      VariantAttribute(
        json["name"] as String,
        (json["values"] as List).cast<String>(),
      );

  @override
  bool operator ==(Object other) =>
      other is VariantAttribute &&
      other.name == name &&
      _listEquals(other.values, values);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(values));
}

/// Biến thể cụ thể đã chọn: tên thuộc tính -> giá trị. VD {"Màu": "Đỏ"}.
typedef VariantSelection = Map<String, String>;

/// Phạm vi áp dụng của một tuỳ chọn mua hàng: tên thuộc tính -> các giá trị
/// được áp dụng. Thuộc tính không có mặt = áp dụng cho MỌI giá trị.
typedef VariantAvailability = Map<String, List<String>>;

/// Các đổi tên khi sửa thuộc tính của linh kiện, để biến thể đang có đi theo
/// tên mới thay vì bị coi là giá trị đã xoá.
class AttributeRenames {
  /// Tên thuộc tính cũ -> mới.
  final Map<String, String> attributes;

  /// Tên thuộc tính CŨ -> (giá trị cũ -> mới).
  final Map<String, Map<String, String>> values;

  const AttributeRenames({this.attributes = const {}, this.values = const {}});

  static const none = AttributeRenames();

  bool get isEmpty =>
      attributes.isEmpty && values.values.every((m) => m.isEmpty);
}

/// Mã hoá/giải mã biến thể (lưu dạng JSON string trong ObjectBox).
class Variants {
  Variants._();

  static List<VariantAttribute> decodeAttributes(String json) {
    if (json.isEmpty) return const [];
    try {
      return [
        for (final item in (jsonDecode(json) as List))
          VariantAttribute.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String encodeAttributes(List<VariantAttribute> attributes) {
    final cleaned = [
      for (final a in attributes)
        if (a.name.trim().isNotEmpty && a.values.isNotEmpty) a,
    ];
    return cleaned.isEmpty
        ? ""
        : jsonEncode(cleaned.map((a) => a.toJson()).toList());
  }

  static VariantSelection decodeSelection(String json) {
    if (json.isEmpty) return const {};
    try {
      return (jsonDecode(json) as Map).cast<String, String>();
    } catch (_) {
      return const {};
    }
  }

  static String encodeSelection(VariantSelection selection) =>
      selection.isEmpty ? "" : jsonEncode(_sorted(selection));

  static VariantAvailability decodeAvailability(String json) {
    if (json.isEmpty) return const {};
    try {
      return (jsonDecode(json) as Map).map(
        (k, v) => MapEntry(k as String, (v as List).cast<String>()),
      );
    } catch (_) {
      return const {};
    }
  }

  static String encodeAvailability(VariantAvailability availability) {
    final cleaned = {
      for (final e in availability.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    };
    return cleaned.isEmpty ? "" : jsonEncode(_sorted(cleaned));
  }

  /// Chỉ giữ các thuộc tính/giá trị còn tồn tại trong [attributes].
  static VariantSelection sanitizeSelection(
    VariantSelection selection,
    List<VariantAttribute> attributes,
  ) => {
    for (final a in attributes)
      if (a.values.contains(selection[a.name])) a.name: selection[a.name]!,
  };

  /// Chỉ giữ các thuộc tính/giá trị còn tồn tại; chọn đủ mọi giá trị = bỏ giới hạn.
  static VariantAvailability sanitizeAvailability(
    VariantAvailability availability,
    List<VariantAttribute> attributes,
  ) {
    final result = <String, List<String>>{};
    for (final a in attributes) {
      final allowed = availability[a.name];
      if (allowed == null) continue;
      final kept = a.values.where(allowed.contains).toList();
      if (kept.isNotEmpty && kept.length < a.values.length) {
        result[a.name] = kept;
      }
    }
    return result;
  }

  /// Tuỳ chọn có áp dụng cho biến thể [selection] không.
  /// Thuộc tính chưa chọn trong [selection] được coi là khớp.
  static bool isAvailable(
    VariantAvailability availability,
    VariantSelection selection,
  ) {
    for (final entry in availability.entries) {
      final chosen = selection[entry.key];
      if (chosen != null && !entry.value.contains(chosen)) return false;
    }
    return true;
  }

  /// Nhãn hiển thị theo thứ tự thuộc tính, VD "Đỏ · 10mm".
  static String label(
    VariantSelection selection, [
    List<VariantAttribute>? attributes,
  ]) {
    final order = attributes?.map((a) => a.name) ?? selection.keys;
    return [
      for (final name in order)
        if (selection[name] != null) selection[name]!,
    ].join(" · ");
  }

  /// Nhãn phạm vi áp dụng, VD "Màu: Đỏ, Xanh". Rỗng = mọi biến thể.
  static String availabilityLabel(VariantAvailability availability) => [
    for (final e in availability.entries) "${e.key}: ${e.value.join(", ")}",
  ].join(" · ");

  /// Khoá ổn định của 1 biến thể (dùng để gộp/so sánh).
  static String key(VariantSelection selection) => encodeSelection(selection);

  /// Mọi tổ hợp biến thể (dùng cho tồn kho). Giới hạn [max] để tránh bùng nổ.
  static List<VariantSelection> combinations(
    List<VariantAttribute> attributes, {
    int max = 200,
  }) {
    var result = <VariantSelection>[{}];
    for (final a in attributes) {
      result = [
        for (final partial in result)
          for (final v in a.values) {...partial, a.name: v},
      ];
      if (result.length > max) return result.sublist(0, max);
    }
    return result;
  }

  /// Đổi tên thuộc tính / giá trị trong 1 lựa chọn biến thể.
  static VariantSelection applyRenames(
    VariantSelection selection,
    AttributeRenames renames,
  ) => {
    for (final e in selection.entries)
      (renames.attributes[e.key] ?? e.key):
          (renames.values[e.key]?[e.value] ?? e.value),
  };

  // --- Sắp xếp giá trị ---

  static const _siPrefixes = {
    "p": 1e-12,
    "n": 1e-9,
    "u": 1e-6,
    "µ": 1e-6,
    "μ": 1e-6,
    "m": 1e-3,
    "k": 1e3,
    "K": 1e3,
    "M": 1e6,
    "G": 1e9,
  };

  // Số ở đầu, tiền tố SI tuỳ chọn, phần thập phân kiểu "4K7", rồi đơn vị
  static final _numberPattern = RegExp(
    r'^\s*([0-9]+(?:[.,][0-9]+)?)\s*([pnuµμmkKMG])?([0-9]+)?\s*(.*)$',
  );

  /// Đọc giá trị số của 1 nhãn: "0.1uF" => (1e-7, "F"), "4K7" => (4700, ""),
  /// "100nF" => (1e-7, "F"), "5mm" => (0.005, "m"). Không bắt đầu bằng số => null.
  static ({double value, String unit})? parseQuantity(String label) {
    final m = _numberPattern.firstMatch(label);
    if (m == null) return null;
    var number = double.parse(m.group(1)!.replaceAll(",", "."));
    var prefix = m.group(2);
    final fraction = m.group(3);
    var unit = m.group(4)!.trim();

    // "4K7" = 4.7K (chỉ khi có tiền tố)
    if (fraction != null) {
      if (prefix == null) return null;
      number = double.parse("${m.group(1)!.replaceAll(",", ".")}.$fraction");
    }
    // Tiền tố đứng một mình là đơn vị khi không có gì phía sau, VD "5m" (mét),
    // trừ k/K/M/G hay dùng cho điện trở ("10K", "1M")
    if (prefix != null && unit.isEmpty && fraction == null) {
      if (!"kKMG".contains(prefix)) {
        unit = prefix;
        prefix = null;
      }
    }
    final scale = prefix == null ? 1.0 : _siPrefixes[prefix]!;
    unit = unit.toLowerCase();
    // Điện trở: "220R", "1K", "10KΩ", "4.7 ohm" cùng 1 đơn vị
    if (const {"r", "ω", "Ω", "ohm"}.contains(unit)) unit = "";
    return (value: number * scale, unit: unit);
  }

  /// So sánh 2 giá trị thuộc tính theo kiểu tự nhiên: theo số (hiểu tiền tố
  /// p/n/u/m/K/M) nếu cả 2 cùng đơn vị, không thì theo chữ (số trong chữ được
  /// so như số: "M2" < "M10").
  static int compareValues(String a, String b) {
    final qa = parseQuantity(a);
    final qb = parseQuantity(b);
    if (qa != null && qb != null && qa.unit == qb.unit) {
      final byValue = qa.value.compareTo(qb.value);
      if (byValue != 0) return byValue;
    } else if (qa != null && qb == null) {
      return -1;
    } else if (qa == null && qb != null) {
      return 1;
    }
    return _naturalCompare(a.toLowerCase(), b.toLowerCase());
  }

  static List<String> sortValues(Iterable<String> values) =>
      values.toList()..sort(compareValues);

  static bool isSorted(List<String> values) {
    for (var i = 1; i < values.length; i++) {
      if (compareValues(values[i - 1], values[i]) > 0) return false;
    }
    return true;
  }

  static final _chunk = RegExp(r'(\d+)|(\D+)');

  static int _naturalCompare(String a, String b) {
    final ca = _chunk.allMatches(a).map((m) => m.group(0)!).toList();
    final cb = _chunk.allMatches(b).map((m) => m.group(0)!).toList();
    for (var i = 0; i < ca.length && i < cb.length; i++) {
      final na = int.tryParse(ca[i]);
      final nb = int.tryParse(cb[i]);
      final c = na != null && nb != null
          ? na.compareTo(nb)
          : ca[i].compareTo(cb[i]);
      if (c != 0) return c;
    }
    return ca.length.compareTo(cb.length);
  }

  static Map<String, T> _sorted<T>(Map<String, T> map) => Map.fromEntries(
    map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
