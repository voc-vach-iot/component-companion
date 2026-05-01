import 'package:intl/intl.dart';

extension CurrencyFormat on num {
  String toVND({bool withCurrency = true}) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: withCurrency ? '₫' : '',
      decimalDigits: 0,
    );
    return formatter.format(this);
  }
}
