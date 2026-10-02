import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/price_record.dart';

/// Phân tích lịch sử giá của 1 tuỳ chọn mua hàng.
class PriceInsight {
  /// Sau bao lâu thì coi là giá "cũ", cần kiểm tra lại.
  static const staleAfter = Duration(days: 60);

  /// Bỏ qua thay đổi nhỏ hơn ngưỡng này khi báo xu hướng.
  static const trendThreshold = 0.05;

  final ComponentOption option;
  final List<PriceRecord> history;

  /// Tỉ lệ thay đổi đơn giá so với mức giá khác gần nhất (0.5 = tăng 50%).
  final double? trend;
  final PriceRecord? previous;

  /// Đơn giá thấp nhất từng ghi nhận.
  final PriceRecord? lowest;

  final DateTime? checkedAt;

  PriceInsight._(
    this.option,
    this.history,
    this.trend,
    this.previous,
    this.lowest,
    this.checkedAt,
  );

  factory PriceInsight.of(ComponentOption option, {DateTime? now}) {
    final history = option.sortedPriceHistory;
    final current = option.pricePerUnit;

    // Mức giá khác gần nhất trước giá hiện tại
    PriceRecord? previous;
    for (final record in history.reversed) {
      if ((record.pricePerUnit - current).abs() > 0.0001) {
        previous = record;
        break;
      }
    }
    double? trend;
    if (previous != null && previous.pricePerUnit > 0) {
      final ratio = current / previous.pricePerUnit - 1;
      if (ratio.abs() >= trendThreshold) trend = ratio;
    }

    PriceRecord? lowest;
    for (final record in history) {
      if (lowest == null || record.pricePerUnit < lowest.pricePerUnit) {
        lowest = record;
      }
    }

    final checkedAt =
        option.priceCheckedAt ??
        (history.isEmpty ? null : history.last.recordedAt);
    return PriceInsight._(option, history, trend, previous, lowest, checkedAt);
  }

  bool get isStale =>
      checkedAt != null && DateTime.now().difference(checkedAt!) > staleAfter;

  String get staleLabel =>
      checkedAt == null ? "" : "Giá từ ${relativeTime(checkedAt!)}";

  String? get trendLabel {
    if (trend == null) return null;
    final percent = (trend! * 100).round();
    if (trend! >= 1) return "x${(trend! + 1).toStringAsFixed(1)}";
    return percent > 0 ? "+$percent%" : "$percent%";
  }

  String? get trendTooltip => previous == null
      ? null
      : "Trước đây ${previous!.pricePerUnit.toVND()}/cái "
            "(${formatDate(previous!.recordedAt)}), nay ${option.pricePerUnit.toVND()}/cái";

  /// "hôm nay", "3 ngày trước", "2 tháng trước", ...
  static String relativeTime(DateTime at, {DateTime? now}) {
    final days = (now ?? DateTime.now()).difference(at).inDays;
    if (days <= 0) return "hôm nay";
    if (days == 1) return "hôm qua";
    if (days < 30) return "$days ngày trước";
    if (days < 365) return "${(days / 30).floor()} tháng trước";
    return "${(days / 365).floor()} năm trước";
  }

  static String formatDate(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return "${two(at.day)}/${two(at.month)}/${at.year}";
  }
}
