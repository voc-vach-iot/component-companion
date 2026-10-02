import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/util/purchase_planner.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:flutter/material.dart';

class ProjectItemCard extends StatelessWidget {
  final ProjectItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Đổi sang tuỳ chọn rẻ hơn (null = không hiện gợi ý).
  final ValueChanged<ComponentOption>? onSwitchOption;

  const ProjectItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.onSwitchOption,
  });

  // Thay thế đoạn build cũ bằng đoạn này
  @override
  Widget build(BuildContext context) {
    final component = item.component.target;
    final option = item.componentOption.target;
    final pricePerUnit =
        (option?.pricePerPack ?? 0) / (option?.unitsPerPack ?? 1);
    final cheaper = PurchasePlanner.cheaperFor(item);
    final variant = item.variant.target;
    final stock = variant?.stock;
    final hasVariants = component?.hasVariants ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // 1. Ảnh (Không bọc Expanded, để cố định width)
          ComponentThumbnail.of(component, size: 40),
          const SizedBox(width: 16),

          // 2. Tên & Quy cách (Expanded là con trực tiếp của Row)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component?.name ?? "Linh kiện",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (hasVariants)
                  Text(
                    variant == null
                        ? "Chưa chọn biến thể"
                        : variant.labelFor(component?.attributes),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: variant == null
                          ? AppColors.warning
                          : AppColors.info,
                    ),
                  ),
                Text(
                  option == null ? "Chưa chọn quy cách" : option.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                if (stock != null)
                  Text(
                    stock >= item.quantity
                        ? "Kho: $stock cái — đủ"
                        : "Kho: $stock cái — thiếu ${item.quantity - stock}",
                    style: TextStyle(
                      fontSize: 11,
                      color: stock >= item.quantity
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                if (cheaper != null && onSwitchOption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: InkWell(
                      onTap: () => onSwitchOption!(cheaper),
                      mouseCursor: SystemMouseCursors.click,
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                          ),
                          children: [
                            const WidgetSpan(
                              child: Icon(
                                Icons.savings_outlined,
                                size: 13,
                                color: AppColors.success,
                              ),
                            ),
                            TextSpan(
                              text:
                                  " Rẻ hơn ${(PurchasePlanner.savingFor(item, cheaper) * 100).round()}% "
                                  "cho ${item.quantity} cái: ${cheaper.displayName} "
                                  "(${PurchasePlanner.singleCost(cheaper, item.quantity).toVND()}) — ",
                            ),
                            const TextSpan(
                              text: "Đổi",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Giá chi tiết (Expanded là con trực tiếp của Row)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${pricePerUnit.toVND()}/cái",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  "${(option?.pricePerPack ?? 0).toVND()}/gói",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // 4. Số lượng (Expanded là con trực tiếp của Row)
          Expanded(
            flex: 1,
            child: Text(
              "x${item.quantity}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          // 5. Tổng tiền (Expanded là con trực tiếp của Row)
          Expanded(
            flex: 1,
            child: Text(
              item.totalPrice.toVND(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),

          // 6. Buttons (Không bọc Expanded)
          const SizedBox(width: 16),
          Row(
            children: [
              AppActionButton(actionType: ActionType.edit, onTap: onEdit),
              AppActionButton(actionType: ActionType.delete, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}
