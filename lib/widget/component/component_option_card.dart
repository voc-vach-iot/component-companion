import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/util/price_insight.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ComponentOptionCard extends StatelessWidget {
  final ComponentOption option;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClone;
  final VoidCallback onConfirmPrice;
  final VoidCallback onShowHistory;

  /// Đơn giá rẻ nhất trong các tuỳ chọn của linh kiện.
  final bool isCheapest;

  const ComponentOptionCard({
    super.key,
    required this.option,
    required this.onEdit,
    required this.onDelete,
    required this.onClone,
    required this.onConfirmPrice,
    required this.onShowHistory,
    this.isCheapest = false,
  });

  Future<void> _openLink(BuildContext context) async {
    final url = Uri.tryParse(option.link);
    if (url != null && await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      AppSnackBar.show(
        context,
        message: "Không thể mở liên kết",
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final insight = PriceInsight.of(option);
    final availability = option.availability;

    // Bấm vào card để sửa nhanh, các thao tác khác trong menu ⋮
    return InkWell(
      onTap: onEdit,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCheapest
                ? AppColors.success.withValues(alpha: 0.6)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // --- Shop, quy cách, nhãn ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        option.shop.isEmpty
                            ? Icons.sell_outlined
                            : Icons.storefront_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          option.shop.isEmpty ? option.name : option.shop,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (option.shop.isNotEmpty)
                    Text(
                      option.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      if (isCheapest)
                        const _Tag("Rẻ nhất", AppColors.success, Icons.star),
                      if (insight.trend != null)
                        _Tag(
                          insight.trendLabel!,
                          insight.trend! > 0
                              ? AppColors.error
                              : AppColors.success,
                          insight.trend! > 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          tooltip: insight.trendTooltip,
                        ),
                      if (insight.isStale)
                        _Tag(
                          insight.staleLabel,
                          AppColors.warning,
                          Icons.schedule,
                          tooltip:
                              "Giá có thể đã thay đổi. Kiểm tra lại trên shop rồi bấm ✓ để xác nhận.",
                        ),
                      if (availability.isNotEmpty)
                        _Tag(
                          Variants.availabilityLabel(availability),
                          AppColors.info,
                          Icons.filter_alt_outlined,
                          tooltip: "Chỉ áp dụng cho các biến thể này",
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // --- Giá ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  option.pricePerPack.toVND(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  "${option.unitsPerPack} cái · ${option.pricePerUnit.toVND()}/cái",
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),

            // --- Hành động ---
            PopupMenuButton<VoidCallback>(
              tooltip: "Thao tác",
              icon: const Icon(Icons.more_vert, size: 18),
              color: AppColors.background,
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                _menu(
                  Icons.check_circle_outline,
                  "Giá vẫn vậy (đã kiểm tra hôm nay)",
                  onConfirmPrice,
                ),
                _menu(Icons.show_chart, "Lịch sử giá", onShowHistory),
                if (option.link.isNotEmpty)
                  _menu(
                    LucideIcons.externalLink,
                    "Mở link shop",
                    () => _openLink(context),
                  ),
                _menu(
                  Icons.copy_rounded,
                  "Nhân bản (nhập giá shop khác)",
                  onClone,
                ),
                _menu(Icons.edit_outlined, "Sửa", onEdit),
                _menu(Icons.delete_outline, "Xoá", onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<VoidCallback> _menu(
    IconData icon,
    String label,
    VoidCallback action,
  ) => PopupMenuItem(
    value: action,
    height: 40,
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(label),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final String? tooltip;

  const _Tag(this.label, this.color, this.icon, {this.tooltip});

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? tag : Tooltip(message: tooltip!, child: tag);
  }
}
