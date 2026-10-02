import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:component_companion/widget/common/highlight_text.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopCard extends StatelessWidget {
  final Shop shop;
  final TextSearch? search;
  final VoidCallback onEdit;
  final VoidCallback onMerge;
  final VoidCallback onDelete;

  const ShopCard({
    super.key,
    required this.shop,
    required this.onEdit,
    required this.onMerge,
    required this.onDelete,
    this.search,
  });

  Future<void> _openLink(BuildContext context) async {
    final url = Uri.tryParse(shop.link);
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
    final options = shop.options;
    final componentCount = options
        .map((o) => o.component.targetId)
        .toSet()
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 20,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HighlightText(
                  shop.name,
                  search: search,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (shop.link.isNotEmpty)
                AppActionButton(
                  icon: LucideIcons.externalLink,
                  tooltip: "Mở trang shop",
                  onTap: () => _openLink(context),
                ),
              AppActionButton(
                icon: Icons.merge_rounded,
                tooltip: "Gộp vào shop khác",
                onTap: onMerge,
              ),
              AppActionButton(actionType: ActionType.edit, onTap: onEdit),
              AppActionButton(actionType: ActionType.delete, onTap: onDelete),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            options.isEmpty
                ? "Chưa có tuỳ chọn mua nào"
                : "${options.length} tuỳ chọn mua · $componentCount linh kiện",
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (shop.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              shop.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
