import 'package:component_companion/model/entities/component_variant.dart';

/// Chia giá 1 combo cho các thành phần.
class ComboPricing {
  ComboPricing._();

  /// Đơn giá mua lẻ rẻ nhất của biến thể (bỏ qua combo), null nếu chưa có.
  static double? referenceUnitPrice(ComponentVariant variant) {
    double? best;
    for (final o in variant.options) {
      if (o.isCombo || o.unitsPerPack <= 0) continue;
      if (best == null || o.pricePerUnit < best) best = o.pricePerUnit;
    }
    return best;
  }

  /// Tỉ lệ giá (tổng = 1) của từng thành phần: theo số cái × đơn giá lẻ tham
  /// khảo; thiếu giá lẻ của bất kỳ thành phần nào thì chia theo số cái.
  static List<double> shares(
    List<({ComponentVariant variant, int quantity})> parts,
  ) {
    final refs = [for (final p in parts) referenceUnitPrice(p.variant)];
    final useRef = refs.every((r) => r != null && r > 0);
    final weights = [
      for (var i = 0; i < parts.length; i++)
        parts[i].quantity * (useRef ? refs[i]! : 1.0),
    ];
    final total = weights.fold(0.0, (a, b) => a + b);
    return [for (final w in weights) total <= 0 ? 0.0 : w / total];
  }
}
