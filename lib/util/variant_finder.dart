import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/util/spec_value.dart';

/// 1 điều kiện lọc biến thể theo thuộc tính: khoảng [min]..[max] (thuộc tính
/// số, VD "18mm" .. "65mm") hoặc tập giá trị [values] (thuộc tính chữ).
class SpecCondition {
  final String attribute;
  final String min;
  final String max;
  final Set<String> values;

  const SpecCondition(
    this.attribute, {
    this.min = "",
    this.max = "",
    this.values = const {},
  });

  SpecCondition copyWith({String? min, String? max, Set<String>? values}) =>
      SpecCondition(
        attribute,
        min: min ?? this.min,
        max: max ?? this.max,
        values: values ?? this.values,
      );

  bool get isEmpty =>
      min.trim().isEmpty && max.trim().isEmpty && values.isEmpty;
}

/// Lọc biến thể của mọi linh kiện theo thông số, kèm đơn giá rẻ nhất để so
/// chi phí (VD pin dung lượng 2000..3500mAh, rẻ nhất / mAh).
class VariantFinder {
  VariantFinder._();

  static String _key(String s) => s.trim().toLowerCase();

  /// Giá trị của thuộc tính [attribute] (không phân biệt hoa thường).
  static String? valueOf(VariantSelection selection, String attribute) {
    final key = _key(attribute);
    for (final e in selection.entries) {
      if (_key(e.key) == key) return e.value;
    }
    return null;
  }

  /// Tên thuộc tính (cách viết gặp đầu tiên) => các giá trị khác nhau, theo
  /// số biến thể có thuộc tính đó giảm dần.
  static Map<String, List<String>> attributeValues(
    Iterable<ComponentVariant> variants,
  ) {
    final names = <String, String>{};
    final values = <String, Map<String, String>>{};
    final counts = <String, int>{};
    for (final v in variants) {
      for (final e in v.selection.entries) {
        final key = _key(e.key);
        names.putIfAbsent(key, () => e.key.trim());
        values
            .putIfAbsent(key, () => {})
            .putIfAbsent(_key(e.value), () => e.value.trim());
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final keys = names.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return {
      for (final k in keys)
        names[k]!: Variants.sortValues(values[k]!.values.toList()),
    };
  }

  /// Thuộc tính dạng số: >= 60% giá trị đọc được số.
  static bool isNumeric(List<String> values) =>
      values.isNotEmpty &&
      values.where((v) => SpecValue.parse(v) != null).length >=
          values.length * 0.6;

  /// Biến thể thoả [condition]. Thiếu thuộc tính => không thoả (điều kiện
  /// chưa nhập gì vẫn lọc ra các biến thể có thuộc tính đó).
  static bool matches(ComponentVariant variant, SpecCondition condition) {
    final raw = valueOf(variant.selection, condition.attribute);
    if (raw == null) return false;
    if (condition.isEmpty) return true;
    if (condition.values.isNotEmpty &&
        !condition.values.map(_key).contains(_key(raw))) {
      return false;
    }
    final min = SpecValue.parse(condition.min);
    final max = SpecValue.parse(condition.max);
    if (min == null && max == null) return true;
    final value = SpecValue.parse(raw);
    if (value == null) return false;
    if (min != null &&
        (!value.comparableTo(min) || value.base < min.base - _eps(min))) {
      return false;
    }
    if (max != null &&
        (!value.comparableTo(max) || value.base > max.base + _eps(max))) {
      return false;
    }
    return true;
  }

  // Sai số làm tròn khi đổi tiền tố (VD 0.1 + 0.2)
  static double _eps(SpecValue v) => v.base.abs() * 1e-9;

  /// Tuỳ chọn mua có đơn giá thấp nhất cho [variant] (bỏ giá 0).
  static ({double unitPrice, ComponentOption option})? cheapest(
    ComponentVariant variant,
  ) {
    ({double unitPrice, ComponentOption option})? best;
    for (final o in variant.options) {
      final price = o.unitPriceFor(variant.id);
      if (price <= 0) continue;
      if (best == null || price < best.unitPrice) {
        best = (unitPrice: price, option: o);
      }
    }
    return best;
  }

  /// Đơn vị thường gặp của thuộc tính số (VD "mAh") để tính giá / đơn vị.
  static String? commonUnit(List<String> values) {
    final counts = <String, int>{};
    for (final v in values) {
      final parsed = SpecValue.parse(v);
      if (parsed == null) continue;
      counts[parsed.label] = (counts[parsed.label] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// Giá trị theo đơn vị [unitLabel] (VD "2Ah" theo "mAh" => 2000); null
  /// nếu không đọc được / khác đơn vị.
  static double? amountIn(String raw, String unitLabel) {
    final value = SpecValue.parse(raw);
    if (value == null) return null;
    final unit = SpecValue.parse("1$unitLabel");
    if (unit == null || !value.comparableTo(unit)) return null;
    return value.base / unit.base;
  }
}
