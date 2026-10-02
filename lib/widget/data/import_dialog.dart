import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Xem trước + chỉnh danh mục / loại trước khi nhập linh kiện từ file.
class ImportDialog extends HookWidget {
  final String fileName;
  final List<ImportPlan> plans;
  final List<Category> categories;
  final List<ComponentType> types;
  final void Function(List<ImportPlan> plans, bool addToStock) onImport;

  const ImportDialog({
    super.key,
    required this.fileName,
    required this.plans,
    required this.categories,
    required this.types,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    // Đổi tham chiếu list để rebuild khi sửa 1 dòng
    final rows = useState(plans);
    final addToStock = useState(false);
    final categoryById = {for (final c in categories) c.id: c};
    final typeById = {for (final t in types) t.id: t};

    void edit(void Function() change) {
      change();
      rows.value = [...rows.value];
    }

    final included = rows.value.where((p) => p.include).toList();
    final newCount = included
        .where((p) => p.existing == null)
        .map((p) => p.row.name.toLowerCase())
        .toSet()
        .length;
    final hasQuantity = rows.value.any((p) => p.row.quantity > 0);

    return AppAlertDialog(
      title: "Nhập linh kiện từ $fileName",
      size: AlertDialogSize.big,
      content: SizedBox(
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${rows.value.length} dòng · sẽ tạo $newCount linh kiện mới, "
              "${included.length - included.where((p) => p.existing == null).length} dòng thêm tùy chọn vào linh kiện có sẵn. "
              "Danh mục / loại được nhận diện theo từ khóa, bấm để sửa.",
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
                const Spacer(),
                if (hasQuantity)
                  Row(
                    children: [
                      Checkbox(
                        value: addToStock.value,
                        onChanged: (v) => addToStock.value = v ?? false,
                      ),
                      const Text("Cộng số lượng đã mua vào tồn kho"),
                    ],
                  ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: rows.value.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = rows.value[i];
                  final row = p.row;
                  return Opacity(
                    opacity: p.include ? 1 : 0.45,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: p.include,
                            onChanged: (v) =>
                                edit(() => p.include = v ?? false),
                          ),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        row.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _Badge(
                                      p.existing == null ? "Mới" : "Đã có",
                                      p.existing == null
                                          ? AppColors.success
                                          : AppColors.info,
                                    ),
                                  ],
                                ),
                                Text(
                                  [
                                    if (row.shop.isNotEmpty) row.shop,
                                    if (row.variant.isNotEmpty) row.variant,
                                    if (row.price > 0)
                                      "${row.price.toVND()}/${row.units} cái",
                                    if (row.quantity > 0) "SL ${row.quantity}",
                                  ].join(" · "),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: _CompactSelect(
                              enabled: p.existing == null,
                              icon: Icons.category_outlined,
                              label:
                                  categoryById[p.categoryId]?.name ??
                                  "Chưa phân loại",
                              items: [0, ...categories.map((c) => c.id)],
                              selected: p.categoryId,
                              labelOf: (id) =>
                                  categoryById[id]?.name ?? "Chưa phân loại",
                              onChanged: (id) => edit(() => p.categoryId = id),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: _CompactSelect(
                              enabled: p.existing == null,
                              icon: Icons.memory_outlined,
                              label:
                                  typeById[p.typeId]?.name ??
                                  "Chưa xác định loại",
                              items: [0, ...types.map((t) => t.id)],
                              selected: p.typeId,
                              labelOf: (id) =>
                                  typeById[id]?.name ?? "Chưa xác định loại",
                              onChanged: (id) => edit(() {
                                p.typeId = id;
                                // Chưa có danh mục thì lấy theo loại
                                final suggested =
                                    typeById[id]?.category.targetId ?? 0;
                                if (p.categoryId == 0 && suggested != 0) {
                                  p.categoryId = suggested;
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
            onImport(rows.value, addToStock.value);
          },
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
class _CompactSelect extends StatelessWidget {
  final bool enabled;
  final IconData icon;
  final String label;
  final List<int> items;
  final int selected;
  final String Function(int id) labelOf;
  final ValueChanged<int> onChanged;

  const _CompactSelect({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SearchPopupAnchor(
      popupWidth: 320,
      popupBuilder: (close) => SearchSelectPopup<int>(
        items: items,
        selected: {selected},
        labelOf: labelOf,
        onTap: (id) {
          close();
          if (id != null) onChanged(id);
        },
        onClose: close,
      ),
      builder: (context, isOpen, toggle) => OutlinedButton.icon(
        onPressed: enabled ? toggle : null,
        icon: Icon(icon, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: selected == 0
              ? AppColors.textMuted
              : AppColors.textMain,
        ),
      ),
    );
  }
}
