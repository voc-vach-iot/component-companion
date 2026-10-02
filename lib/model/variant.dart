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
