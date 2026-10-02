import 'dart:math' as math;

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/util/price_insight.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:flutter/material.dart';

/// Lịch sử đơn giá của 1 tuỳ chọn: biểu đồ + bảng.
class PriceHistoryDialog extends StatelessWidget {
  final ComponentOption option;

  const PriceHistoryDialog({super.key, required this.option});

  @override
  Widget build(BuildContext context) {
    final insight = PriceInsight.of(option);
    final history = insight.history;
    final title = [
      if (option.shop.isNotEmpty) option.shop,
      option.name,
    ].join(" · ");

    return AppAlertDialog(
      title: "Lịch sử giá",
      size: AlertDialogSize.big,
      content: SizedBox(
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _Stat("Hiện tại", "${option.pricePerUnit.toVND()}/cái"),
                if (insight.lowest != null)
                  _Stat(
                    "Thấp nhất",
                    "${insight.lowest!.pricePerUnit.toVND()}/cái",
                    sub: PriceInsight.formatDate(insight.lowest!.recordedAt),
                  ),
                if (insight.checkedAt != null)
                  _Stat(
                    "Kiểm tra gần nhất",
                    PriceInsight.relativeTime(insight.checkedAt!),
                    sub: PriceInsight.formatDate(insight.checkedAt!),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (history.length >= 2)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(painter: _PriceChartPainter(history)),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text("Chưa có lịch sử giá"))
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        // Mới nhất trước
                        final record = history[history.length - 1 - index];
                        final older = index + 1 < history.length
                            ? history[history.length - 2 - index]
                            : null;
                        final change = older == null || older.pricePerUnit == 0
                            ? null
                            : record.pricePerUnit / older.pricePerUnit - 1;
                        return ListTile(
                          dense: true,
                          title: Text(
                            "${record.pricePerUnit.toVND()}/cái",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "${record.pricePerPack.toVND()} / gói ${record.unitsPerPack} cái",
                          ),
                          leading: Text(
                            PriceInsight.formatDate(record.recordedAt),
                          ),
                          trailing: change == null || change.abs() < 0.005
                              ? const Text(
                                  "—",
                                  style: TextStyle(color: AppColors.textMuted),
                                )
                              : Text(
                                  "${change > 0 ? "+" : ""}${(change * 100).round()}%",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: change > 0
                                        ? AppColors.error
                                        : AppColors.success,
                                  ),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;

  const _Stat(this.label, this.value, {this.sub});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      if (sub != null)
        Text(
          sub!,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
    ],
  );
}

/// Biểu đồ bậc thang đơn giá theo thời gian.
class _PriceChartPainter extends CustomPainter {
  final List<PriceRecord> history;

  _PriceChartPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    const padding = EdgeInsets.fromLTRB(4, 8, 4, 18);
    final chart = padding.deflateRect(Offset.zero & size);

    final start = history.first.recordedAt.millisecondsSinceEpoch.toDouble();
    final end = math.max(
      DateTime.now().millisecondsSinceEpoch.toDouble(),
      start + 1,
    );
    final prices = history.map((r) => r.pricePerUnit).toList();
    final minPrice = prices.reduce(math.min) * 0.9;
    final maxPrice = math.max(prices.reduce(math.max) * 1.05, minPrice + 1);

    double x(DateTime t) =>
        chart.left +
        (t.millisecondsSinceEpoch - start) / (end - start) * chart.width;
    double y(double price) =>
        chart.bottom -
        (price - minPrice) / (maxPrice - minPrice) * chart.height;

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(chart.bottomLeft, chart.bottomRight, grid);

    // Đường bậc thang: giá giữ nguyên tới lần ghi tiếp theo
    final path = Path()
      ..moveTo(x(history.first.recordedAt), y(history.first.pricePerUnit));
    for (var i = 1; i < history.length; i++) {
      path
        ..lineTo(x(history[i].recordedAt), y(history[i - 1].pricePerUnit))
        ..lineTo(x(history[i].recordedAt), y(history[i].pricePerUnit));
    }
    path.lineTo(chart.right, y(history.last.pricePerUnit));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.info
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    final dot = Paint()..color = AppColors.info;
    for (final r in history) {
      canvas.drawCircle(Offset(x(r.recordedAt), y(r.pricePerUnit)), 3, dot);
    }

    void label(String text, Offset at, {bool alignRight = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, alignRight ? at - Offset(painter.width, 0) : at);
    }

    label(
      PriceInsight.formatDate(history.first.recordedAt),
      Offset(chart.left, chart.bottom + 3),
    );
    label("Hôm nay", Offset(chart.right, chart.bottom + 3), alignRight: true);
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter old) =>
      old.history != history;
}
