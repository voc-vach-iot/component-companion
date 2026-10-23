import 'dart:io';

import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/util/bookmarklet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(Bookmarklet.shopeeOrdersAsset).readAsStringSync();

  test("đóng gói: bỏ comment, mã hoá URL, gộp 1 dòng vẫn hợp lệ", () async {
    final url = Bookmarklet.build(source);
    expect(url, startsWith("javascript:"));
    final code = Uri.decodeComponent(url.substring("javascript:".length));
    expect(code, isNot(contains("/*")));
    expect(code, isNot(contains("\n")));

    final dir = await Directory.systemTemp.createTemp("cc_bm_");
    addTearDown(() => dir.delete(recursive: true));
    final file = File("${dir.path}/bookmarklet.js")..writeAsStringSync(code);
    final result = await Process.run("node", ["--check", file.path]);
    expect(result.exitCode, 0, reason: "${result.stderr}");
  }, skip: Process.runSync("which", ["node"]).exitCode != 0);

  test("JSON bookmarklet xuất ra được trang nhập đọc đúng", () {
    const json = '''[
 {"Tên linh kiện": "Điện trở 1/4W 10K", "Thuộc tính": "Giá trị=10K",
  "Phân loại": "Gói 100 cái",
  "Số cái/gói": 100, "Giá gói": 15000, "Số lượng mua": 2,
  "Shop": "Linh Kiện ABC", "Link": "https://shopee.vn/product/111/9"}
]''';
    final row = ImportService.parse(json).single;
    expect(row.name, "Điện trở 1/4W 10K");
    expect(row.packName, "Gói 100 cái");
    expect(row.attributes, {"Giá trị": "10K"});
    expect(row.units, 100);
    expect(row.price, 15000);
    expect(row.quantity, 2);
    expect(row.shop, "Linh Kiện ABC");
    expect(row.link, "https://shopee.vn/product/111/9");
  });

  test("cột Trạng thái / Nguồn: đơn đang giao => đang về, shop có hậu tố", () {
    const json = '''[
 {"Tên linh kiện": "Tụ 100nF", "Số lượng mua": 1, "Shop": "Linh Kiện ABC",
  "Link": "", "Trạng thái": "Chờ giao hàng", "Nguồn": "Shopee"}
]''';
    final row = ImportService.parse(json).single;
    expect(row.status, "Chờ giao hàng");
    expect(row.delivery, ImportDelivery.pending);
    expect(row.shopName, "Linh Kiện ABC (Shopee)");
  });
}
