import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/service/stock_reservation.dart';
import 'package:component_companion/util/purchase_planner.dart';
import 'package:component_companion/widget/button/action_button.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/model/unit.dart';
import 'package:flutter/material.dart';

class ProjectItemCard extends StatelessWidget {
  final ProjectItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Đổi sang tuỳ chọn rẻ hơn (null = không hiện gợi ý).
  final ValueChanged<ComponentOption>? onSwitchOption;

  /// Kho của biến thể đang giữ cho dự án "Đang thực hiện" khác.
  final List<StockHold> reservedElsewhere;

  /// Đổi số lượng nhanh bằng nút +/− (null = chỉ hiển thị).
  final ValueChanged<int>? onQuantityChanged;

  const ProjectItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.onSwitchOption,
    this.onQuantityChanged,
    this.reservedElsewhere = const [],
  });

  // Thay thế đoạn build cũ bằng đoạn này
  @override
  Widget build(BuildContext context) {
    final component = item.component.target;
    final option = item.componentOption.target;
    final cheaper = PurchasePlanner.cheaperFor(item);
    final variant = item.variant.target;
    final stock = variant?.stock;
    final unit = variant?.unit ?? component?.quantityUnit ?? QuantityUnit.piece;
    final hasVariants = component?.hasVariants ?? false;
    final reserved = reservedElsewhere.fold(0, (s, h) => s + h.quantity);
    final available = stock == null
        ? 0
        : (stock - reserved > 0 ? stock - reserved : 0);

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
                  Tooltip(
                    message: reserved == 0
                        ? ""
                        : "Đang giữ cho: ${StockReservations.describe(reservedElsewhere)}",
                    child: Text(
                      [
                        "Kho: ${unit.format(stock)}",
                        if (reserved > 0)
                          "giữ $reserved cho dự án khác, còn $available",
                        available >= item.quantity
                            ? "đủ"
                            : "thiếu ${item.quantity - available}",
                      ].join(" — "),
                      style: TextStyle(
                        fontSize: 11,
                        color: available >= item.quantity
                            ? AppColors.success
                            : AppColors.warning,
                      ),
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
                                  "cho ${unit.format(item.quantity)}: ${cheaper.displayName} "
                                  "(${PurchasePlanner.singleCost(cheaper, item.quantity, variantId: item.variant.targetId).toVND()}) — ",
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
                  option?.unitPriceText(item.variant.targetId) ??
                      "0₫/${unit.label}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  "${(option?.pricePerPack ?? 0).toVND()}/${option?.isCombo ?? false ? "combo" : "gói"}",
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
            child: onQuantityChanged == null
                ? Text(
                    "x${item.quantity}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  )
                : _QuantityStepper(
                    quantity: item.quantity,
                    onChanged: onQuantityChanged!,
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

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tooltip, int? next) => IconButton(
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: EdgeInsets.zero,
      onPressed: next == null ? null : () => onChanged(next),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            Icons.remove_rounded,
            "Bớt 1",
            quantity > 1 ? quantity - 1 : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text(
              "$quantity",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          button(Icons.add_rounded, "Thêm 1", quantity + 1),
        ],
      ),
    );
  }
}
