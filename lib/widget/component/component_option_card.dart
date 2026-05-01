import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ComponentOptionCard extends StatelessWidget {
  final ComponentOption option;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ComponentOptionCard({
    super.key,
    required this.option,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface, // Giữ consistency với CategoryItem
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // --- Tên và Link ---
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    option.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (option.link.isNotEmpty)
                  AppActionButton(
                    icon: LucideIcons.externalLink,
                    onTap: () async {
                      final Uri url = Uri.parse(option.link);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (context.mounted) {
                          AppSnackBar.show(
                            context,
                            message: "Không thể mở liên kết",
                            type: SnackBarType.error,
                          );
                        }
                      }
                    },
                    tooltip: option.link, // Hiển thị link khi hover
                  ),
              ],
            ),
          ),

          // --- Giá và Actions ---
          Row(
            children: [
              // --- Phần hiển thị Giá ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Giá tổng của cả gói
                  Text(
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: '₫',
                      decimalDigits: 0,
                    ).format(option.pricePerPack),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  // Giá trên từng đơn vị (đơn giá)
                  if (option.unitsPerPack >= 1)
                    Text(
                      "${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(option.pricePerUnit)}/cái",
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors
                            .textDisabled, // Màu xám để không gây nhiễu
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              AppActionButton(actionType: ActionType.edit, onTap: onEdit),
              const SizedBox(width: 4),
              AppActionButton(actionType: ActionType.delete, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}
