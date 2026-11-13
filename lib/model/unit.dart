import 'package:component_companion/extension/format/num.dart';

/// Đơn vị đo số lượng của linh kiện. Số lượng luôn lưu dạng số nguyên theo
/// đơn vị nhỏ nhất ([scale] lần đơn vị hiển thị): cái = 1, m = cm (×100),
/// kg = g (×1000), lít = ml (×1000).
enum QuantityUnit {
  piece("", "cái", 0),
  meter("m", "mét", 2),
  kilogram("kg", "kg", 3),
  liter("l", "lít", 3);

  /// Giá trị lưu trong [Component.unit] (rỗng = cái).
  final String key;

  /// Tên hiển thị cạnh số: "12 cái", "1,5 m".
  final String label;

  /// Số chữ số thập phân khi hiển thị (số lưu = số hiển thị × 10^decimals).
  final int decimals;

  const QuantityUnit(this.key, this.label, this.decimals);

  /// Hệ số quy đổi: số lưu = số hiển thị × scale.
  int get scale {
    var s = 1;
    for (var i = 0; i < decimals; i++) {
      s *= 10;
    }
    return s;
  }

  bool get isPiece => this == piece;

  /// Nhãn đơn giá: "đ/cái", "đ/m".
  String get priceLabel => "đ/$label";

  static QuantityUnit of(String key) =>
      values.where((u) => u.key == key).firstOrNull ?? piece;

  /// Số lưu -> chữ, VD 150 (m) -> "1,5"; bỏ số 0 thừa. Không kèm đơn vị.
  String formatNumber(int raw) {
    if (decimals == 0) return raw.toString();
    final negative = raw < 0;
    final abs = raw.abs();
    final whole = abs ~/ scale;
    final frac = (abs % scale).toString().padLeft(decimals, "0");
    final trimmed = frac.replaceFirst(RegExp(r"0+$"), "");
    final text = trimmed.isEmpty ? "$whole" : "$whole,$trimmed";
    return negative ? "-$text" : text;
  }

  /// Đơn giá theo số lưu (đ / đơn vị nhỏ nhất) -> "1.500₫/m".
  String pricePer(double rawPrice) => "${(rawPrice * scale).toVND()}/$label";

  /// Số lưu -> "12 cái" / "1,5 m".
  String format(int raw) => "${formatNumber(raw)} $label";

  /// Chữ -> số lưu. Nhận "1,5" / "1.5", hậu tố đơn vị phụ (cm, mm cho mét;
  /// g cho kg; ml cho lít) và hậu tố chính ("m", "kg", "l", "cái"). Trả null
  /// nếu không đọc được. Số lẻ thừa được làm tròn.
  int? parse(String input) {
    var text = input.trim().toLowerCase().replaceAll(" ", "");
    if (text.isEmpty) return null;
    var factor = 1.0;
    final suffix = RegExp(r"([a-zà-ỹ]+)$").firstMatch(text)?.group(1);
    if (suffix != null) {
      final f = _suffixFactor(suffix);
      if (f == null) return null;
      factor = f;
      text = text.substring(0, text.length - suffix.length);
    }
    final value = double.tryParse(text.replaceAll(",", "."));
    if (value == null) return null;
    return (value * factor * scale).round();
  }

  /// Hệ số so với đơn vị chính khi gõ kèm hậu tố (null = hậu tố lạ).
  double? _suffixFactor(String suffix) => switch ((this, suffix)) {
    (piece, "cái" || "cai" || "c" || "pcs") => 1,
    (meter, "m") => 1,
    (meter, "cm") => 0.01,
    (meter, "mm") => 0.001,
    (kilogram, "kg") => 1,
    (kilogram, "g") => 0.001,
    (liter, "l" || "lít" || "lit") => 1,
    (liter, "ml") => 0.001,
    _ => null,
  };
}
