/// Quy ước tên shop: shop trên Shopee có hậu tố " (Shopee)" để phân biệt với
/// cửa hàng ngoài cùng tên (xem docs/quy-tac-linh-kien.md).
class ShopName {
  ShopName._();

  static const shopeeSuffix = "(Shopee)";
  static final _suffix = RegExp(
    r'\s*\(\s*shopee\s*\)\s*$',
    caseSensitive: false,
  );

  static bool isShopee(String name) => _suffix.hasMatch(name);

  /// Tên không có hậu tố.
  static String base(String name) =>
      name.trim().replaceFirst(_suffix, "").trim();

  /// Tên có hậu tố (không thêm 2 lần). Rỗng => rỗng.
  static String shopee(String name) {
    final b = base(name);
    return b.isEmpty ? "" : "$b $shopeeSuffix";
  }
}
