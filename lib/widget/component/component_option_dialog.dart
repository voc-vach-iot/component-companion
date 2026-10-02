import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Tuỳ chọn mua hàng = 1 "chào giá" của 1 shop: quy cách gói, giá, link, áp
/// dụng cho 1 hoặc nhiều biến thể (VD "Gói 20 cái" dùng chung cho 5mm, 8mm).
class ComponentOptionDialog extends HookWidget {
  final Component component;

  /// Sửa tuỳ chọn này (null = thêm mới).
  final ComponentOption? option;

  /// Điền sẵn từ tuỳ chọn khác (nhân bản). Chỉ lưu khi bấm Thêm.
  final ComponentOption? prefill;

  /// Biến thể chọn sẵn khi thêm mới (VD đang xem 1 biến thể).
  final Set<int> initialVariantIds;

  final List<Shop> shops;

  /// Tạo shop mới từ tên gõ trong ô chọn shop.
  final Future<Shop?> Function(String name) onCreateShop;

  /// Trả về true nếu lưu thành công (khi đó dialog tự đóng).
  final Future<bool> Function(ComponentOption option) onSave;

  const ComponentOptionDialog({
    super.key,
    required this.component,
    required this.shops,
    required this.onCreateShop,
    required this.onSave,
    this.option,
    this.prefill,
    this.initialVariantIds = const {},
  });

  /// Đọc số tiền người dùng gõ: "20.000", "20,000", "20000đ" => 20000.
  static int parseMoney(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final isEdit = option != null;
    final source = option ?? prefill;
    final variants = useMemoized(() => component.sortedVariants);
    final attributes = component.attributes;
    final pickVariants = component.hasVariants;

    final shopList = useState<List<Shop>>(shops);
    final shop = useState<Shop?>(
      source == null
          ? null
          : shops.where((s) => s.id == source.shop.targetId).firstOrNull,
    );
    final nameCtrl = useTextEditingController(text: source?.name ?? "");
    final unitsCtrl = useTextEditingController(
      text: source?.unitsPerPack.toString() ?? "1",
    );
    final priceCtrl = useTextEditingController(
      text: source == null ? "" : source.pricePerPack.toString(),
    );
    final linkCtrl = useTextEditingController(text: source?.link ?? "");
    final selected = useState<Set<int>>(
      source != null
          ? source.variants.map((v) => v.id).toSet()
          : initialVariantIds.isNotEmpty
          ? initialVariantIds
          : variants.length == 1
          ? {variants.first.id}
          : const {},
    );
    final saving = useState(false);

    final units = int.tryParse(useValueListenable(unitsCtrl).text) ?? 0;
    final price = parseMoney(useValueListenable(priceCtrl).text);
    final name = useValueListenable(nameCtrl).text.trim();
    final unitPrice = units > 0 ? price / units : null;

    final effectiveName = name.isEmpty ? defaultName(units) : name;
    final identityChanged =
        isEdit &&
        (option!.shop.targetId != (shop.value?.id ?? 0) ||
            option!.unitsPerPack != units ||
            option!.name.trim() != effectiveName);
    final priceChanged = isEdit && option!.pricePerPack != price;

    final canSave = units > 0 && (!pickVariants || selected.value.isNotEmpty);

    Future<void> save() async {
      if (!canSave || saving.value) return;
      saving.value = true;
      final target = option ?? ComponentOption(name: "", pricePerPack: 0);
      target
        ..name = effectiveName
        ..unitsPerPack = units
        ..pricePerPack = price
        ..link = linkCtrl.text.trim();
      target.component.targetId = component.id;
      target.shop.targetId = shop.value?.id ?? 0;
      target.variants
        ..clear()
        ..addAll(variants.where((v) => selected.value.contains(v.id)));
      final ok = await onSave(target);
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    return AppAlertDialog(
      title: isEdit
          ? "Sửa tuỳ chọn mua"
          : prefill != null
          ? "Nhân bản tuỳ chọn mua"
          : "Thêm tuỳ chọn mua",
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prefill != null) ...[
                const _Hint(
                  "Đã điền sẵn từ tuỳ chọn cũ. Sửa shop / giá / biến thể rồi bấm "
                  "Thêm — tuỳ chọn mới có lịch sử giá riêng.",
                ),
                const SizedBox(height: 10),
              ],
              AppSearchSelect<Shop>(
                label: "Shop",
                items: shopList.value,
                value: shop.value,
                labelOf: (s) => s.name,
                noneLabel: "Chưa ghi shop",
                hintText: "Chọn hoặc gõ tên để tạo shop",
                leadingOf: (_) => const Icon(
                  Icons.storefront_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                onChanged: (s) => shop.value = s,
                onCreate: (name) async {
                  final created = await onCreateShop(name);
                  if (created == null) return;
                  shopList.value = [...shopList.value, created];
                  shop.value = created;
                },
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: "Quy cách (VD: Gói 20 cái)",
                controller: nameCtrl,
                hintText: defaultName(units),
                autofocus: !isEdit,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: "Số cái / gói",
                      controller: unitsCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: "Giá cả gói (₫)",
                      controller: priceCtrl,
                      hintText: "VD: 25.000",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  children: [
                    const TextSpan(text: "Đơn giá: "),
                    TextSpan(
                      text: unitPrice == null
                          ? "—"
                          : "${unitPrice.toVND()}/cái",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    if (identityChanged)
                      const TextSpan(
                        text:
                            "  · Đổi shop / quy cách => lịch sử giá bắt đầu lại từ giá này",
                      )
                    else if (priceChanged)
                      TextSpan(
                        text:
                            "  · Trước: ${option!.pricePerPack.toVND()}, giá cũ được lưu vào lịch sử",
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: "Link mua hàng",
                controller: linkCtrl,
                keyboardType: TextInputType.url,
              ),
              if (pickVariants) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Áp dụng cho biến thể (${selected.value.length}/${variants.length})",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: () => selected.value =
                          selected.value.length == variants.length
                          ? const {}
                          : variants.map((v) => v.id).toSet(),
                      child: Text(
                        selected.value.length == variants.length
                            ? "Bỏ chọn"
                            : "Chọn tất cả",
                      ),
                    ),
                  ],
                ),
                if (variants.isEmpty)
                  const _Hint(
                    "Linh kiện chưa có biến thể nào. Hãy tạo biến thể trước.",
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final v in variants)
                            FilterChip(
                              label: Text(v.labelFor(attributes)),
                              visualDensity: VisualDensity.compact,
                              selected: selected.value.contains(v.id),
                              onSelected: (_) {
                                final next = {...selected.value};
                                next.contains(v.id)
                                    ? next.remove(v.id)
                                    : next.add(v.id);
                                selected.value = next;
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: isEdit ? "Lưu thay đổi" : "Thêm mới",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: !canSave || saving.value,
          onPressed: save,
        ),
      ],
    );
  }

  static String defaultName(int units) =>
      units <= 1 ? "1 cái" : "Gói $units cái";
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.info.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}
