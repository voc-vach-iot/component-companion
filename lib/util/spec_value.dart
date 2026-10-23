/// Giá trị số của 1 thông số biến thể, VD "10K" => 10000, "2000mAh" => 2
/// (Ah), "4K7" => 4700, "2,2uF" => 2.2e-6. Dùng để lọc theo khoảng và so
/// giá / đơn vị.
class SpecValue {
  /// Giá trị đã đổi theo tiền tố (đơn vị gốc, VD Ah, F, m).
  final double base;

  /// Đơn vị không kèm tiền tố, VD "Ah", "F", "m"; rỗng = số trần.
  final String unit;

  /// Tiền tố như cách viết, VD "m" trong "mAh"; rỗng = không có.
  final String prefix;

  const SpecValue(this.base, {this.unit = "", this.prefix = ""});

  static const _prefixes = {
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

  /// Kiểu ghi điện trở "4K7", "2R2", "1M5".
  static final _rkm = RegExp(r'^(\d+)([RKkM])(\d+)\b');

  static final _number = RegExp(
    r'(-?\d+(?:[.,]\d+)?)\s*([A-Za-zµμΩ°%][A-Za-zµμΩ°%]*)?',
  );

  /// Đọc số đầu tiên trong [text]; null nếu không có số.
  static SpecValue? parse(String text) {
    final s = text.trim();
    if (s.isEmpty) return null;
    final rkm = _rkm.firstMatch(s);
    if (rkm != null) {
      final mult = rkm[2] == "R" ? 1.0 : _prefixes[rkm[2]]!;
      return SpecValue(
        double.parse("${rkm[1]}.${rkm[3]}") * mult,
        prefix: rkm[2] == "R" ? "" : rkm[2]!,
      );
    }
    final m = _number.firstMatch(s);
    if (m == null) return null;
    final number = double.tryParse(m[1]!.replaceAll(",", "."));
    if (number == null) return null;
    var letters = m[2] ?? "";
    // "50x50x0.5mm": "x" nối kích thước, không phải đơn vị
    if (letters == "x" || letters == "X") letters = "";
    if (letters.isEmpty) return SpecValue(number);
    final first = letters[0];
    final rest = letters.substring(1);
    // Chữ đầu là tiền tố khi đứng 1 mình ("10K") hoặc trước đơn vị ("mAh");
    // "cm" => centi-mét
    if (letters == "cm") {
      return SpecValue(number * 1e-2, unit: "m", prefix: "c");
    }
    if (_prefixes.containsKey(first) && (rest.isEmpty || _isUnit(rest))) {
      return SpecValue(number * _prefixes[first]!, unit: rest, prefix: first);
    }
    return SpecValue(number, unit: letters);
  }

  /// Đơn vị hay gặp (sau tiền tố).
  static bool _isUnit(String s) => const {
    "A",
    "Ah",
    "V",
    "W",
    "Wh",
    "F",
    "H",
    "Hz",
    "Ω",
    "ohm",
    "Ohm",
    "m",
    "g",
    "s",
    "B",
    "b",
    "bps",
  }.contains(s);

  /// Hai giá trị so được với nhau (cùng đơn vị, hoặc 1 bên là số trần).
  bool comparableTo(SpecValue other) =>
      unit.isEmpty || other.unit.isEmpty || unit == other.unit;

  /// Nhãn đơn vị như cách viết, VD "mAh".
  String get label => "$prefix$unit";
}
