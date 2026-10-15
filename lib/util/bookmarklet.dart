/// Đóng gói mã JS thành bookmarklet (`javascript:...`) để dán vào bookmark.
class Bookmarklet {
  Bookmarklet._();

  static const shopeeOrdersAsset = "assets/bookmarklet/shopee_orders.js";

  /// Bỏ comment khối, khoảng trắng đầu dòng, dòng trống rồi mã hoá URL.
  /// Mã nguồn chỉ dùng comment khối và luôn có dấu `;` nên vẫn chạy đúng kể
  /// cả khi trình duyệt gộp thành 1 dòng.
  static String build(String source) {
    final compact = source
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), "")
        .split("\n")
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join("\n");
    return "javascript:${Uri.encodeComponent(compact)}";
  }
}
