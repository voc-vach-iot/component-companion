/// Đóng gói mã JS thành bookmarklet (`javascript:...`) để dán vào bookmark.
class Bookmarklet {
  Bookmarklet._();

  static const shopeeOrdersAsset = "assets/bookmarklet/shopee_orders.js";

  /// Bỏ comment khối, khoảng trắng đầu dòng, dòng trống, gộp thành 1 dòng
  /// rồi mã hoá URL. Mã nguồn chỉ dùng comment khối và luôn có dấu `;` nên
  /// gộp dòng vẫn chạy đúng.
  static String build(String source) {
    final compact = source
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), "")
        .split("\n")
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join(" ");
    return "javascript:${Uri.encodeComponent(compact)}";
  }
}
