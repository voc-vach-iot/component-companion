import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Tuỳ chọn mua hàng = 1 "chào giá" của 1 shop: quy cách gói, giá, link.
/// Mặc định áp dụng cho mọi biến thể của linh kiện; chỉ giới hạn khi shop
/// bán giá khác nhau theo biến thể.
class ComponentOptionDialog extends HookWidget {
  final Component component;
  final ComponentOption? option; // Null = Thêm, Có giá trị = Sửa
  final Function(ComponentOption) onSave;

  /// Tên các shop đã từng nhập để gợi ý.
  final List<String> knownShops;

  const ComponentOptionDialog({
    super.key,
    required this.component,
    this.option,
    required this.onSave,
    this.knownShops = const [],
  });

  /// Đọc số tiền người dùng gõ: "20.000", "20,000", "20000đ" => 20000.
  static int parseMoney(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final isEditMode = option != null;
    final attributes = component.attributes;

    final shopCtrl = useTextEditingController(text: option?.shop ?? "");
    final nameCtrl = useTextEditingController(text: option?.name ?? "");
    final unitsCtrl = useTextEditingController(
      text: option?.unitsPerPack.toString() ?? "1",
    );
    final priceCtrl = useTextEditingController(
      text: option?.pricePerPack.toString() ?? "",
    );
    final linkCtrl = useTextEditingController(text: option?.link ?? "");
    final availability = useState<VariantAvailability>(
      option?.availability ?? const {},
    );

    final units = int.tryParse(useValueListenable(unitsCtrl).text) ?? 0;
    final price = parseMoney(useValueListenable(priceCtrl).text);
    final unitPrice = units > 0 ? price / units : null;
    final oldUnitPrice = option?.pricePerUnit;
    final priceChanged =
        isEditMode &&
        (price != option!.pricePerPack || units != option!.unitsPerPack);

    final canSave =
        useValueListenable(nameCtrl).text.trim().isNotEmpty ||
        useValueListenable(shopCtrl).text.trim().isNotEmpty;

    /// Giá trị đang được áp dụng của 1 thuộc tính (không có = tất cả).
    List<String> selectedOf(VariantAttribute a) =>
        availability.value[a.name] ?? a.values;

    void toggle(VariantAttribute a, String value) {
      final current = [...selectedOf(a)];
      current.contains(value) ? current.remove(value) : current.add(value);
      if (current.isEmpty) return; // phải áp dụng cho ít nhất 1 giá trị
      availability.value = Variants.sanitizeAvailability({
        ...availability.value,
        a.name: current,
      }, attributes);
    }

    return AppAlertDialog(
      title: isEditMode ? "Sửa tùy chọn mua hàng" : "Thêm tùy chọn mua hàng",
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShopField(controller: shopCtrl, knownShops: knownShops),
              const SizedBox(height: 10),
              AppTextField(
                label: "Phân loại / quy cách (VD: Gói 100 cái)",
                controller: nameCtrl,
                autofocus: !isEditMode,
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
                    if (priceChanged &&
                        unitPrice != null &&
                        oldUnitPrice != null &&
                        oldUnitPrice > 0)
                      TextSpan(
                        text:
                            "  (trước: ${oldUnitPrice.toVND()}/cái, "
                            "${_percent(unitPrice / oldUnitPrice)} — giá cũ sẽ được lưu vào lịch sử)",
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

              if (attributes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  "Áp dụng cho biến thể",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  availability.value.isEmpty
                      ? "Mọi biến thể cùng giá. Chỉ bỏ chọn khi shop bán giá khác theo biến thể."
                      : "Chỉ áp dụng: ${Variants.availabilityLabel(availability.value)}",
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                for (final a in attributes) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          "${a.name}:",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      for (final value in a.values)
                        FilterChip(
                          label: Text(
                            value,
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                          selected: selectedOf(a).contains(value),
                          onSelected: (_) => toggle(a, value),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: isEditMode ? "Lưu thay đổi" : "Thêm mới",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: !canSave || units <= 0,
          onPressed: () async {
            final newOption =
                option ?? ComponentOption(name: "", pricePerPack: 0);

            newOption.shop = shopCtrl.text.trim();
            newOption.name = nameCtrl.text.trim().isEmpty
                ? "Gói $units cái"
                : nameCtrl.text.trim();
            newOption.unitsPerPack = units;
            newOption.pricePerPack = price;
            newOption.link = linkCtrl.text.trim();
            newOption.availability = availability.value;

            // Gán link component
            newOption.component.targetId = component.id;

            await onSave(newOption);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }

  static String _percent(double ratio) {
    final diff = ((ratio - 1) * 100).round();
    if (diff == 0) return "không đổi";
    return diff > 0 ? "tăng $diff%" : "giảm ${-diff}%";
  }
}

/// Ô nhập tên shop có gợi ý từ các shop đã dùng.
class _ShopField extends HookWidget {
  final TextEditingController controller;
  final List<String> knownShops;

  const _ShopField({required this.controller, required this.knownShops});

  @override
  Widget build(BuildContext context) {
    final focusNode = useFocusNode();
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.border),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Shop",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) => RawAutocomplete<String>(
            textEditingController: controller,
            focusNode: focusNode,
            optionsBuilder: (value) {
              final query = value.text.trim().toLowerCase();
              return knownShops.where(
                (s) => query.isEmpty || s.toLowerCase().contains(query),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: "VD: Linh kiện ABC (Shopee)",
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: border,
                    enabledBorder: border,
                    prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                  ),
                ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 220,
                    maxWidth: constraints.maxWidth,
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final shop in options)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.storefront_outlined),
                          title: Text(shop),
                          onTap: () => onSelected(shop),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
