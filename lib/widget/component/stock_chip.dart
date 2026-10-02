import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:flutter/material.dart';

/// Chip tình trạng tồn kho của linh kiện. Bấm để nhập kho.
class StockChip extends StatelessWidget {
  final Component component;
  final VoidCallback? onTap;

  const StockChip({super.key, required this.component, this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = component.stockTotal;
    final threshold = component.lowStockThreshold;

    final (String label, Color color, IconData icon) = switch (total) {
      null => ("Nhập kho", AppColors.textMuted, Icons.inventory_2_outlined),
      0 => ("Hết hàng", AppColors.error, Icons.remove_shopping_cart_outlined),
      _ when threshold > 0 && total <= threshold => (
        "Sắp hết: $total",
        AppColors.warning,
        Icons.warning_amber_rounded,
      ),
      _ => ("Kho: $total", AppColors.success, Icons.inventory_2_outlined),
    };

    final locations = {
      for (final s in component.stockItems)
        if (s.location.isNotEmpty) s.location,
    };

    return Tooltip(
      message: total == null
          ? "Chưa theo dõi tồn kho. Bấm để nhập."
          : [
              "Tồn kho: $total cái",
              if (threshold > 0) "Cảnh báo khi ≤ $threshold",
              if (locations.isNotEmpty) "Vị trí: ${locations.join(", ")}",
            ].join("\n"),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
