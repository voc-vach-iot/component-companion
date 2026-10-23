/// Ngăn của khay có vách tháo được (VD khay F0: 3 khe, tháo vách thành 2 ngăn
/// to + nhỏ hoặc 1 ngăn).
///
/// Khay có [slots] khe bằng nhau, giữa 2 khe liền nhau là 1 vách. [removed] là
/// mặt nạ bit: bit i = 1 nghĩa là vách giữa khe i và khe i + 1 đã tháo.
class Compartments {
  Compartments._();

  /// Số khe mỗi ngăn, theo thứ tự. VD 3 khe, tháo vách 0 => [2, 1].
  static List<int> sizes(int slots, int removed) {
    if (slots <= 1) return const [1];
    final result = <int>[];
    var size = 1;
    for (var i = 0; i < slots - 1; i++) {
      if (removed & (1 << i) != 0) {
        size++;
      } else {
        result.add(size);
        size = 1;
      }
    }
    result.add(size);
    return result;
  }

  /// Ngăn chứa khe [slot].
  static int ofSlot(int slots, int removed, int slot) {
    final s = sizes(slots, removed);
    var end = 0;
    for (var i = 0; i < s.length; i++) {
      end += s[i];
      if (slot < end) return i;
    }
    return s.length - 1;
  }

  /// Khe đầu tiên của ngăn [compartment].
  static int firstSlot(int slots, int removed, int compartment) {
    final s = sizes(slots, removed);
    var start = 0;
    for (var i = 0; i < compartment && i < s.length; i++) {
      start += s[i];
    }
    return start;
  }

  /// Mọi cách tháo vách (mặt nạ) của khay [slots] khe.
  static List<int> allLayouts(int slots) =>
      slots <= 1 ? const [0] : [for (var m = 0; m < 1 << (slots - 1); m++) m];

  /// Mô tả ngắn, VD "3 ngăn", "To | nhỏ", "1 ngăn".
  static String describe(int slots, int removed) {
    final s = sizes(slots, removed);
    if (s.length == 1) return "1 ngăn";
    if (s.every((x) => x == s.first)) return "${s.length} ngăn";
    if (s.length == 2) return s.first > s.last ? "To | nhỏ" : "Nhỏ | to";
    return s.map((x) => "$x").join(" | ");
  }
}
