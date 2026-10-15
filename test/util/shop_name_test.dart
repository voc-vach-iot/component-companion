import 'package:component_companion/util/shop_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("thêm hậu tố (Shopee) đúng 1 lần", () {
    expect(ShopName.shopee("Flash Electric"), "Flash Electric (Shopee)");
    expect(
      ShopName.shopee("Flash Electric (Shopee)"),
      "Flash Electric (Shopee)",
    );
    expect(
      ShopName.shopee(" Flash Electric ( shopee ) "),
      "Flash Electric (Shopee)",
    );
    expect(ShopName.shopee(""), "");
    expect(ShopName.base("ABC (SHOPEE)"), "ABC");
    expect(ShopName.isShopee("ABC (Shopee)"), isTrue);
    expect(ShopName.isShopee("ABC"), isFalse);
  });
}
