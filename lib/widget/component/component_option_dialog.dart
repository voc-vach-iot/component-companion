import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/combo_part.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/util/combo_pricing.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/util/component_search.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
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

  /// Tạo biến thể mới ngay trong dialog (quên tạo trước). null = ẩn nút.
  final Future<ComponentVariant?> Function()? onCreateVariant;

  /// Trả về true nếu lưu thành công (khi đó dialog tự đóng).
  final Future<bool> Function(ComponentOption option) onSave;

  /// Mọi biến thể của mọi linh kiện (chọn thành phần combo).
  final List<ComponentVariant> Function()? allVariants;

  /// Tạo linh kiện mới ngay trong ô chọn thành phần combo, trả về biến thể
  /// của nó (null nếu huỷ / linh kiện có biến thể cần tạo trước).
  final Future<ComponentVariant?> Function(String name)? onCreateComponent;

  const ComponentOptionDialog({
    super.key,
    required this.component,
    required this.shops,
    required this.onCreateShop,
    this.onCreateVariant,
    required this.onSave,
    this.option,
    this.prefill,
    this.initialVariantIds = const {},
    this.allVariants,
    this.onCreateComponent,
  });

  /// Đọc số tiền người dùng gõ: "20.000", "20,000", "20000đ" => 20000.
  static int parseMoney(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final isEdit = option != null;
    final source = option ?? prefill;
    // Danh sách cục bộ để biến thể tạo thêm trong dialog hiện ngay
    final variantList = useState(useMemoized(() => component.sortedVariants));
    final variants = variantList.value;
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
    // --- Combo: 1 gói gồm nhiều linh kiện / biến thể ---
    final pool = useState<List<ComponentVariant>>(
      useMemoized(() => allVariants?.call() ?? variants),
    );
    final isCombo = useState(source?.isCombo ?? false);
    final parts = useState<List<_Part>>([
      for (final p in source?.parts ?? const <ComboPart>[])
        if (p.variant.target case final v?) _Part(v, p.quantity),
    ]);
    void toggleCombo(bool on) {
      isCombo.value = on;
      if (on && parts.value.isEmpty) {
        // Bắt đầu từ biến thể đang chọn của linh kiện này
        final q = int.tryParse(unitsCtrl.text) ?? 1;
        parts.value = [
          for (final v in variants)
            if (selected.value.contains(v.id) || variants.length == 1)
              _Part(v, q <= 0 ? 1 : q),
        ];
      }
    }

    final units = int.tryParse(useValueListenable(unitsCtrl).text) ?? 0;
    final price = parseMoney(useValueListenable(priceCtrl).text);
    final name = useValueListenable(nameCtrl).text.trim();
    final unitPrice = units > 0 ? price / units : null;
    final validParts = parts.value.where((p) => p.quantity > 0).toList();
    final effectiveName = name.isNotEmpty
        ? name
        : isCombo.value
        ? "Combo"
        : defaultName(units);
    final identityChanged =
        isEdit &&
        (option!.shop.targetId != (shop.value?.id ?? 0) ||
            option!.unitsPerPack != (isCombo.value ? 1 : units) ||
            option!.name.trim() != effectiveName);
    final priceChanged = isEdit && option!.pricePerPack != price;

    final canSave = isCombo.value
        ? validParts.isNotEmpty
        : units > 0 && (!pickVariants || selected.value.isNotEmpty);

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
      if (isCombo.value) {
        // Repository gắn biến thể + số cái gói theo thành phần
        target.draftParts = [
          for (final p in validParts)
            ComboPart(quantity: p.quantity)..variant.targetId = p.variant.id,
        ];
      } else {
        target.draftParts = const [];
        target.variants
          ..clear()
          ..addAll(variants.where((v) => selected.value.contains(v.id)));
      }
      final ok = await onSave(target);
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    Future<void> createVariant() async {
      final created = await onCreateVariant!();
      if (created == null || !context.mounted) return;
      variantList.value = [...variantList.value, created];
      selected.value = {...selected.value, created.id};
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
              const SizedBox(height: 4),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: isCombo.value,
                onChanged: toggleCombo,
                title: const Text("Combo / bộ (1 gói gồm nhiều linh kiện)"),
                subtitle: const Text(
                  "VD LCD1602 + module I2C, 1 cặp XT60 đực + cái, vít kèm ốc",
                  style: TextStyle(fontSize: 11),
                ),
              ),
              if (isCombo.value) ...[
                AppTextField(
                  label: "Giá cả combo (₫)",
                  controller: priceCtrl,
                  hintText: "VD: 45.000",
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _ComboEditor(
                  parts: parts.value,
                  pool: pool.value,
                  price: price,
                  onChanged: (next) => parts.value = next,
                  onCreateComponent: onCreateComponent == null
                      ? null
                      : (name) async {
                          final v = await onCreateComponent!(name);
                          if (v != null) pool.value = [...pool.value, v];
                          return v;
                        },
                ),
              ] else ...[
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
              ],
              const SizedBox(height: 10),
              AppTextField(
                label: "Link mua hàng",
                controller: linkCtrl,
                keyboardType: TextInputType.url,
              ),
              if (pickVariants && !isCombo.value) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Áp dụng cho biến thể (${selected.value.length}/${variants.length})",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (onCreateVariant != null)
                      TextButton.icon(
                        onPressed: createVariant,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Biến thể mới"),
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
                  _Hint(
                    onCreateVariant == null
                        ? "Linh kiện chưa có biến thể nào. Hãy tạo biến thể trước."
                        : "Linh kiện chưa có biến thể nào. Bấm \"Biến thể mới\" để tạo ngay.",
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

/// 1 thành phần combo đang sửa.
class _Part {
  final ComponentVariant variant;
  final int quantity;

  const _Part(this.variant, this.quantity);
}

/// Nhãn "Tên linh kiện · biến thể".
String _variantLabel(ComponentVariant v) {
  final c = v.component.target;
  if (c == null) return v.label;
  return v.isDefault ? c.name : "${c.name} · ${v.labelFor(c.attributes)}";
}

/// Danh sách thành phần combo: chọn biến thể (linh kiện bất kỳ) + số cái.
class _ComboEditor extends StatelessWidget {
  final List<_Part> parts;
  final List<ComponentVariant> pool;
  final int price;
  final ValueChanged<List<_Part>> onChanged;
  final Future<ComponentVariant?> Function(String name)? onCreateComponent;

  const _ComboEditor({
    required this.parts,
    required this.pool,
    required this.price,
    required this.onChanged,
    this.onCreateComponent,
  });

  @override
  Widget build(BuildContext context) {
    final shares = ComboPricing.shares([
      for (final p in parts) (variant: p.variant, quantity: p.quantity),
    ]);
    void replace(int i, _Part? part) => onChanged([
      for (var j = 0; j < parts.length; j++)
        if (j != i) parts[j] else ?part,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Trong 1 combo có (${parts.length} loại)",
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < parts.length; i++)
          Padding(
            key: ValueKey(("combo-part", i, parts.length)),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppSearchSelect<ComponentVariant>(
                    label: "Thành phần ${i + 1}",
                    items: pool,
                    value: parts[i].variant,
                    labelOf: _variantLabel,
                    keywordsOf: ComponentSearch.variantKeywords,
                    leadingOf: (v) => switch (v.component.target) {
                      final c? => ComponentThumbnail.of(c, size: 28),
                      null => const SizedBox(width: 28),
                    },
                    subtitleOf: (v) =>
                        v.stock == null ? "Chưa nhập kho" : "Kho: ${v.stock}",
                    hintText: "Chọn hoặc gõ tên để tạo linh kiện",
                    onChanged: (v) {
                      if (v != null) replace(i, _Part(v, parts[i].quantity));
                    },
                    onCreate: onCreateComponent == null
                        ? null
                        : (name) async {
                            final v = await onCreateComponent!(name);
                            if (v != null) {
                              replace(i, _Part(v, parts[i].quantity));
                            }
                          },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: TextFormField(
                      initialValue: "${parts[i].quantity}",
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Số cái",
                        isDense: true,
                      ),
                      onChanged: (t) => replace(
                        i,
                        _Part(parts[i].variant, int.tryParse(t.trim()) ?? 0),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: IconButton(
                    tooltip: "Bỏ khỏi combo",
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => replace(i, null),
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: pool.isEmpty
              ? null
              : () => onChanged([
                  ...parts,
                  _Part(
                    pool.firstWhere(
                      (v) => !parts.any((p) => p.variant.id == v.id),
                      orElse: () => pool.first,
                    ),
                    1,
                  ),
                ]),
          icon: const Icon(Icons.add, size: 16),
          label: const Text("Thêm linh kiện vào combo"),
        ),
        if (price > 0 && parts.isNotEmpty)
          Text(
            "Giá chia (theo giá mua lẻ, thiếu thì theo số cái): ${[for (var i = 0; i < parts.length; i++)
              if (parts[i].quantity > 0) "${_variantLabel(parts[i].variant)} ≈ ${(price * shares[i] / parts[i].quantity).toVND()}/cái"].join(" · ")}",
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
      ],
    );
  }
}
