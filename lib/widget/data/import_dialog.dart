import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Xem trước trước khi nhập linh kiện từ file / clipboard: mỗi dòng được
/// khớp với linh kiện có sẵn (theo link, tên hoặc đoán) hoặc tạo mới; sửa được
/// linh kiện, biến thể, danh mục / loại.
class ImportDialog extends HookWidget {
  final String fileName;
  final List<ImportPlan> plans;
  final List<Category> categories;
  final List<ComponentType> types;
  final List<Component> components;

  /// Shop cũ thiếu hậu tố "(Shopee)" theo các dòng đang chọn.
  final List<ImportShopHint> Function(List<ImportPlan> plans)? shopHints;
  final void Function(List<ImportPlan> plans, bool addToStock, bool renameShops)
  onImport;

  const ImportDialog({
    super.key,
    required this.fileName,
    required this.plans,
    required this.categories,
    required this.types,
    required this.components,
    required this.onImport,
    this.shopHints,
  });

  @override
  Widget build(BuildContext context) {
    // Đổi tham chiếu list để rebuild khi sửa 1 dòng
    final rows = useState(plans);
    final addToStock = useState(false);
    final renameShops = useState(true);
    final categoryById = {for (final c in categories) c.id: c};
    final typeById = {for (final t in types) t.id: t};

    void edit(void Function() change) {
      change();
      rows.value = [...rows.value];
    }

    final included = rows.value.where((p) => p.include).toList();
    final newCount = included
        .where((p) => p.existing == null)
        .map((p) => p.name.trim().toLowerCase())
        .toSet()
        .length;
    final matchedCount = included.where((p) => p.existing != null).length;
    final priceCount = included.where((p) => p.linkedOption != null).length;
    final hasQuantity = rows.value.any((p) => p.row.quantity > 0);
    final pendingCount = included
        .where(
          (p) => p.row.quantity > 0 && p.row.delivery == ImportDelivery.pending,
        )
        .length;
    final hints = shopHints?.call(rows.value) ?? const <ImportShopHint>[];
    final renames = hints.where((h) => !h.merge).toList();
    final merges = hints.where((h) => h.merge).toList();

    Future<void> newVariant(ImportPlan p) async {
      final selection = await showDialog<VariantSelection>(
        context: context,
        builder: (_) =>
            _VariantValuesDialog(component: p.existing!, initial: p.attributes),
      );
      if (selection == null) return;
      edit(() {
        p.attributes = selection;
        p.variantId = null;
      });
    }

    Widget rowView(ImportPlan p) {
      final row = p.row;
      final component = p.existing;
      final linked = p.linkedOption;
      final (badge, badgeColor, reason) = switch (p.match) {
        _ when component == null => (
          "Tạo mới",
          AppColors.success,
          "Không tìm thấy linh kiện giống — sẽ tạo linh kiện mới",
        ),
        _ when linked != null => (
          "Cập nhật giá",
          AppColors.info,
          "Cùng link với tùy chọn \"${linked.displayName}\" — chỉ cập nhật giá, giá cũ vào lịch sử giá",
        ),
        ImportMatch.link => (
          "Khớp sẵn",
          AppColors.info,
          "Cùng link sản phẩm với 1 tùy chọn mua của linh kiện này",
        ),
        ImportMatch.name => ("Khớp sẵn", AppColors.info, "Trùng tên"),
        ImportMatch.manual => ("Khớp sẵn", AppColors.info, "Đã chọn tay"),
        _ => (
          "Khớp sẵn?",
          AppColors.warning,
          "Đoán theo từ trong tên — kiểm tra lại",
        ),
      };
      final priceChange =
          linked != null &&
              row.price > 0 &&
              (linked.pricePerPack != row.price ||
                  linked.unitsPerPack != row.units)
          ? "${linked.pricePerPack.toVND()}/${linked.unitsPerPack} → "
          : "";

      final variants = component?.sortedVariants ?? const <ComponentVariant>[];
      final variant = variants.where((v) => v.id == p.variantId).firstOrNull;
      final coversAll =
          component != null &&
          component.attributes.every(
            (a) => p.attributes.keys.any(
              (k) => k.toLowerCase() == a.name.toLowerCase(),
            ),
          );
      final variantLabel = variant != null
          ? variant.labelFor(component!.attributes)
          : linked != null && p.attributes.isEmpty
          ? "Giữ biến thể của tùy chọn"
          : p.attributes.isNotEmpty && coversAll
          ? "Theo dòng: ${Variants.label(p.attributes)}"
          : "Chưa chọn — áp cho mọi biến thể khớp";

      return Opacity(
        opacity: p.include ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: p.include,
                onChanged: (v) => edit(() => p.include = v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            row.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: reason,
                          child: _Badge(badge, badgeColor),
                        ),
                      ],
                    ),
                    Text(
                      [
                        if (row.shopName.isNotEmpty) row.shopName,
                        if (row.attributes.isNotEmpty) row.attributesLabel,
                        if (row.packName.isNotEmpty) row.packName,
                        if (row.price > 0)
                          "$priceChange${row.price.toVND()}/${row.units} cái",
                        if (row.quantity > 0) "SL ${row.quantity}",
                        if (row.status.isNotEmpty)
                          switch (row.delivery) {
                            ImportDelivery.pending => "${row.status} → đang về",
                            ImportDelivery.cancelled =>
                              "${row.status} → không cộng kho",
                            ImportDelivery.received => row.status,
                          },
                      ].join(" · "),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _CompactSelect<Component>(
                            icon: Icons.inventory_2_outlined,
                            label: component?.name ?? "Tạo mới: ${p.name}",
                            items: components,
                            selected: component,
                            labelOf: (c) => c.name,
                            leadingOf: (c) =>
                                ComponentThumbnail.of(c, size: 28),
                            noneLabel: "Tạo linh kiện mới",
                            onCreate: (name) => edit(() {
                              p.selectComponent(null);
                              p.name = name.trim().isEmpty ? row.name : name;
                            }),
                            onChanged: (c) => edit(() {
                              p.selectComponent(c);
                              if (c == null) p.name = row.name;
                              if (c != null) {
                                p.categoryId = c.category.targetId;
                                p.typeId = c.type.targetId;
                              }
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (component == null) ...[
                          Expanded(
                            flex: 2,
                            child: _CompactSelect<int>(
                              icon: Icons.category_outlined,
                              label:
                                  categoryById[p.categoryId]?.name ??
                                  "Chưa phân loại",
                              items: [0, ...categories.map((c) => c.id)],
                              selected: p.categoryId,
                              labelOf: (id) =>
                                  categoryById[id]?.name ?? "Chưa phân loại",
                              onChanged: (id) =>
                                  edit(() => p.categoryId = id ?? 0),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _CompactSelect<int>(
                              icon: Icons.memory_outlined,
                              label:
                                  typeById[p.typeId]?.name ??
                                  "Chưa xác định loại",
                              items: [0, ...types.map((t) => t.id)],
                              selected: p.typeId,
                              labelOf: (id) =>
                                  typeById[id]?.name ?? "Chưa xác định loại",
                              onChanged: (id) => edit(() {
                                p.typeId = id ?? 0;
                                // Chưa có danh mục thì lấy theo loại
                                final suggested =
                                    typeById[p.typeId]?.category.targetId ?? 0;
                                if (p.categoryId == 0 && suggested != 0) {
                                  p.categoryId = suggested;
                                }
                              }),
                            ),
                          ),
                        ] else if (component.hasVariants) ...[
                          Expanded(
                            flex: 4,
                            child: _CompactSelect<ComponentVariant>(
                              icon: Icons.tune_rounded,
                              label: variantLabel,
                              warning:
                                  variant == null &&
                                  !(linked != null && p.attributes.isEmpty) &&
                                  !(p.attributes.isNotEmpty && coversAll),
                              items: variants,
                              selected: variant,
                              labelOf: (v) => v.labelFor(component.attributes),
                              onChanged: (v) => edit(() {
                                if (v == null) return;
                                p.variantId = v.id;
                                p.attributes = row.attributes;
                              }),
                            ),
                          ),
                          IconButton(
                            tooltip: "Biến thể mới",
                            icon: const Icon(Icons.add_rounded, size: 20),
                            onPressed: () => newVariant(p),
                          ),
                        ] else
                          const Expanded(
                            flex: 4,
                            child: Text(
                              "Không có biến thể",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppAlertDialog(
      title: "Nhập linh kiện từ $fileName",
      size: AlertDialogSize.big,
      content: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${rows.value.length} dòng · tạo $newCount linh kiện mới · "
              "$matchedCount dòng khớp linh kiện có sẵn"
              "${priceCount > 0 ? " ($priceCount dòng cập nhật giá theo link)" : ""}. "
              "Linh kiện được khớp theo link, tên hoặc đoán theo từ trong tên — bấm để đổi.",
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => edit(() {
                    for (final p in rows.value) {
                      p.include = true;
                    }
                  }),
                  child: const Text("Chọn tất cả"),
                ),
                TextButton(
                  onPressed: () => edit(() {
                    for (final p in rows.value) {
                      p.include = false;
                    }
                  }),
                  child: const Text("Bỏ chọn tất cả"),
                ),
                if (hasQuantity)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Checkbox(
                          value: addToStock.value,
                          onChanged: (v) => addToStock.value = v ?? false,
                        ),
                        Flexible(
                          child: Text(
                            pendingCount > 0
                                ? "Cộng số lượng đã mua vào tồn kho "
                                      "($pendingCount dòng đơn chưa giao → đang về)"
                                : "Cộng số lượng đã mua vào tồn kho",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (renames.isNotEmpty)
              Row(
                children: [
                  Checkbox(
                    value: renameShops.value,
                    onChanged: (v) => renameShops.value = v ?? false,
                  ),
                  Expanded(
                    child: Text(
                      "Đổi tên shop cũ cho đúng quy ước: "
                      "${renames.map((h) => "${h.from} → ${h.to}").join(", ")}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            if (merges.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "Có cả 2 tên cho cùng shop: "
                  "${merges.map((h) => "\"${h.from}\" và \"${h.to}\"").join(", ")}. "
                  "Hàng Shopee sẽ vào shop có hậu tố — nên \"Gộp vào\" ở trang Shop.",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: rows.value.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => rowView(rows.value[i]),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Nhập ${included.length} dòng",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: included.isEmpty,
          onPressed: () {
            Navigator.pop(context);
            onImport(rows.value, addToStock.value, renameShops.value);
          },
        ),
      ],
    );
  }
}

/// Nhập giá trị từng thuộc tính cho biến thể mới.
class _VariantValuesDialog extends HookWidget {
  final Component component;
  final VariantSelection initial;

  const _VariantValuesDialog({required this.component, required this.initial});

  @override
  Widget build(BuildContext context) {
    final attributes = component.attributes;
    final controllers = [
      for (final a in attributes)
        useTextEditingController(
          text: initial.entries
              .where((e) => e.key.toLowerCase() == a.name.toLowerCase())
              .firstOrNull
              ?.value,
        ),
    ];
    // Vẽ lại để bật / tắt nút khi gõ
    useListenable(Listenable.merge(controllers));
    final complete = controllers.every((c) => c.text.trim().isNotEmpty);

    return AppAlertDialog(
      title: "Biến thể mới cho ${component.name}",
      size: AlertDialogSize.small,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < attributes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: controllers[i],
                autofocus: i == 0,
                decoration: InputDecoration(
                  labelText: attributes[i].name,
                  helperText: attributes[i].values.isEmpty
                      ? null
                      : "Đã có: ${attributes[i].values.join(", ")}",
                ),
              ),
            ),
        ],
      ),
      actions: [
        AppButton(
          label: "Dùng biến thể này",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: !complete,
          onPressed: () => Navigator.pop(context, {
            for (var i = 0; i < attributes.length; i++)
              attributes[i].name: controllers[i].text.trim(),
          }),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
    ),
  );
}

/// Ô chọn gọn (1 dòng) có tìm kiếm, dùng trong bảng.
class _CompactSelect<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<T> items;
  final T? selected;
  final String Function(T item) labelOf;
  final Widget Function(T item)? leadingOf;
  final ValueChanged<T?> onChanged;

  /// Khác null => có dòng "không chọn" (trả về null).
  final String? noneLabel;
  final ValueChanged<String>? onCreate;
  final bool warning;

  const _CompactSelect({
    required this.icon,
    required this.label,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.leadingOf,
    this.noneLabel,
    this.onCreate,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = selected;
    return SearchPopupAnchor(
      popupWidth: 360,
      popupBuilder: (close) => SearchSelectPopup<T>(
        items: items,
        selected: {?value},
        labelOf: labelOf,
        leadingOf: leadingOf,
        noneLabel: noneLabel,
        onTap: (item) {
          close();
          if (item != null || noneLabel != null) onChanged(item);
        },
        onCreate: onCreate == null
            ? null
            : (text) {
                close();
                onCreate!(text);
              },
        onClose: close,
      ),
      builder: (context, isOpen, toggle) => OutlinedButton.icon(
        onPressed: toggle,
        icon: Icon(icon, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: warning
              ? AppColors.warning
              : value == null || value == 0
              ? AppColors.textMuted
              : AppColors.textMain,
        ),
      ),
    );
  }
}
