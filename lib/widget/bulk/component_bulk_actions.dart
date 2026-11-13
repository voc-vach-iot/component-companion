import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/unit.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/bulk_edit_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/widget/bulk/bulk_rename_dialog.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/catalog_loader.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/input/dropdown.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:component_companion/widget/notification/bulk_undo_toast.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Các thao tác hàng loạt trên nhóm linh kiện đang chọn ở trang Linh kiện.
class ComponentBulkActions {
  ComponentBulkActions._();

  static final _db = ObjectboxService.instance;

  static void _fail(BuildContext context, Object e) {
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: e is AppException ? e.message : "$e",
      type: SnackBarType.error,
    );
  }

  // --- Đổi tên linh kiện ---

  static Future<void> renameComponents(
    BuildContext context,
    List<int> ids,
  ) async {
    final box = _db.get<Component>();
    final selected = box.getMany(ids).whereType<Component>().toList();
    final taken = {
      for (final c in box.getAll())
        if (!ids.contains(c.id)) c.name,
    };
    final names = await BulkRenameDialog.show(
      context,
      title: "Đổi tên ${selected.length} linh kiện",
      items: [
        for (final c in selected)
          RenameItem(
            id: c.id,
            oldName: c.name,
            vars: {"n": "", "dv": c.quantityUnit.label},
          ),
      ],
      takenNames: taken,
    );
    if (names == null || !context.mounted) return;
    try {
      final undo = BulkEditService().renameComponents(names);
      BulkUndoToast.show(
        context,
        message: "Đã đổi tên ${names.length} linh kiện",
        undo: undo,
      );
    } catch (e) {
      _fail(context, e);
    }
  }

  // --- Đổi tên tuỳ chọn mua ---

  static Future<void> renameOptions(BuildContext context, List<int> ids) async {
    final options = _db
        .get<ComponentOption>()
        .query(ComponentOption_.component.anyOf(ids))
        .findAndClose()
        .where((o) => !o.isCombo)
        .toList();
    if (options.isEmpty) {
      AppSnackBar.show(
        context,
        message: "Các linh kiện đã chọn chưa có tuỳ chọn mua thường",
        type: SnackBarType.info,
      );
      return;
    }
    final names = await BulkRenameDialog.show(
      context,
      title: "Đổi tên ${options.length} tuỳ chọn mua",
      items: [
        for (final o in options)
          RenameItem(
            id: o.id,
            oldName: o.name,
            subtitle: [
              o.component.target?.name ?? "",
              o.shop.target?.name ?? "",
            ].where((s) => s.isNotEmpty).join(" · "),
            vars: {
              "n": o.unit.formatNumber(o.unitsPerPack),
              "dv": o.unit.label,
            },
          ),
      ],
      templateVars: const ["n", "dv"],
      templateHint: "Gói {n} {dv}",
    );
    if (names == null || !context.mounted) return;
    try {
      final undo = BulkEditService().renameOptions(names);
      BulkUndoToast.show(
        context,
        message: "Đã đổi tên ${names.length} tuỳ chọn mua",
        undo: undo,
      );
    } catch (e) {
      _fail(context, e);
    }
  }

  // --- Gán danh mục / loại / đơn vị / ngưỡng ---

  static Future<void> assign(BuildContext context, List<int> ids) async {
    final components = _db
        .get<Component>()
        .getMany(ids)
        .whereType<Component>()
        .toList();
    final units = {for (final c in components) c.unit};
    final result = await showDialog<_AssignResult>(
      context: context,
      builder: (_) => CatalogLoader(
        builder: (categories, types) => _AssignDialog(
          count: components.length,
          categories: categories,
          types: types,
          commonUnit: units.length == 1 ? QuantityUnit.of(units.first) : null,
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      final service = BulkEditService();
      final undo = BulkUndo();
      final assigned = service.assign(
        ids,
        categoryId: result.categoryId,
        typeId: result.typeId,
        threshold: result.threshold,
      );
      undo.add(assigned.run);
      var message = "Đã cập nhật ${ids.length} linh kiện";
      if (result.unit != null) {
        final unitUndo = service.changeUnit(ids, result.unit!);
        undo.add(unitUndo.run);
        message += ", đơn vị ${result.unit!.label}";
      }
      BulkUndoToast.show(context, message: message, undo: undo);
    } catch (e) {
      _fail(context, e);
    }
  }

  // --- Giá trị thuộc tính của biến thể ---

  /// [variantIds] null = mọi biến thể của [ids]; khác null = chỉ các biến thể đó.
  static Future<void> setAttribute(
    BuildContext context,
    List<int> ids, {
    List<int>? variantIds,
  }) async {
    final components = _db
        .get<Component>()
        .getMany(ids)
        .whereType<Component>()
        .toList();
    final values = <String, List<String>>{};
    for (final c in components) {
      for (final a in c.attributes) {
        final list = values.putIfAbsent(a.name, () => []);
        for (final v in a.values) {
          if (!list.contains(v)) list.add(v);
        }
      }
    }
    if (values.isEmpty) {
      AppSnackBar.show(
        context,
        message: "Các linh kiện đã chọn chưa có thuộc tính biến thể",
        type: SnackBarType.info,
      );
      return;
    }
    final targets =
        variantIds ??
        [
          for (final v
              in _db
                  .get<ComponentVariant>()
                  .query(ComponentVariant_.component.anyOf(ids))
                  .findAndClose())
            v.id,
        ];
    await showDialog<void>(
      context: context,
      builder: (_) => _AttributeDialog(
        attributeValues: values,
        variantIds: targets,
        onDone: (message, undo) {
          if (context.mounted) {
            BulkUndoToast.show(context, message: message, undo: undo);
          }
        },
      ),
    );
  }

  // --- Xoá ---

  static void delete(BuildContext context, WidgetRef ref, List<int> ids) {
    showDialog(
      context: context,
      builder: (_) => ConfirmDeleteDialog(
        title: "Xóa ${ids.length} linh kiện",
        content:
            "Xóa ${ids.length} linh kiện đã chọn cùng biến thể, tồn kho, tùy "
            "chọn mua và lịch sử giá? Có thể hoàn tác ngay sau khi xoá.",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(componentIds: ids),
          delete: () async {
            final notifier = ref.read(componentProvider.notifier);
            var ok = true;
            for (final id in ids) {
              ok = await notifier.deleteComponent(id) && ok;
            }
            return ok;
          },
          message: "Đã xóa ${ids.length} linh kiện",
        ),
      ),
    );
  }
}

class _AssignResult {
  final int? categoryId;
  final int? typeId;
  final QuantityUnit? unit;
  final int? threshold;

  const _AssignResult({
    this.categoryId,
    this.typeId,
    this.unit,
    this.threshold,
  });
}

class _AssignDialog extends HookWidget {
  static const _keep = -1;

  final int count;
  final List<Category> categories;
  final List<ComponentType> types;

  /// Đơn vị chung của các linh kiện (null = lẫn nhiều đơn vị, ẩn ô ngưỡng).
  final QuantityUnit? commonUnit;

  const _AssignDialog({
    required this.count,
    required this.categories,
    required this.types,
    required this.commonUnit,
  });

  @override
  Widget build(BuildContext context) {
    final category = useState(_keep);
    final type = useState(_keep);
    final unit = useState<QuantityUnit?>(null);
    final thresholdCtrl = useTextEditingController();
    useListenable(thresholdCtrl);

    final effectiveUnit = unit.value ?? commonUnit;
    final thresholdText = thresholdCtrl.text.trim();
    final threshold = thresholdText.isEmpty
        ? null
        : effectiveUnit?.parse(thresholdText);
    final thresholdBad = thresholdText.isNotEmpty && threshold == null;

    DropdownMenuItem<int> item(int id, String label) => DropdownMenuItem(
      value: id,
      child: Text(label, overflow: TextOverflow.ellipsis),
    );

    final nothing =
        category.value == _keep &&
        type.value == _keep &&
        unit.value == null &&
        threshold == null;

    return AppAlertDialog(
      title: "Cập nhật $count linh kiện",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDropdown<int>(
            label: "Danh mục",
            isExpanded: true,
            initialValue: category.value,
            items: [
              item(_keep, "— Giữ nguyên —"),
              item(0, "— Chưa phân loại —"),
              for (final c in categories) item(c.id, c.name),
            ],
            onChanged: (v) => category.value = v ?? _keep,
          ),
          const SizedBox(height: 12),
          AppDropdown<int>(
            label: "Loại linh kiện",
            isExpanded: true,
            initialValue: type.value,
            items: [
              item(_keep, "— Giữ nguyên —"),
              item(0, "— Không có loại —"),
              for (final t in types) item(t.id, t.name),
            ],
            onChanged: (v) => type.value = v ?? _keep,
          ),
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: "Đơn vị đo",
            isExpanded: true,
            initialValue: unit.value?.key ?? "keep",
            items: [
              const DropdownMenuItem(
                value: "keep",
                child: Text("— Giữ nguyên —"),
              ),
              for (final u in QuantityUnit.values)
                DropdownMenuItem(value: u.key, child: Text(u.label)),
            ],
            onChanged: (v) => unit.value = v == null || v == "keep"
                ? null
                : QuantityUnit.of(v),
          ),
          if (unit.value != null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "Số hiển thị giữ nguyên (12 cái → 12 m); số lưu, giá/đơn vị "
                "được quy đổi theo.",
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          if (effectiveUnit != null) ...[
            const SizedBox(height: 12),
            AppTextField(
              label: "Ngưỡng cảnh báo sắp hết (${effectiveUnit.label})",
              controller: thresholdCtrl,
              hintText: "Để trống = giữ nguyên",
            ),
            if (thresholdBad)
              const Text(
                "Số không hợp lệ",
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: "Áp dụng",
          size: ButtonSize.small,
          isDisabled: nothing || thresholdBad,
          onPressed: () => Navigator.pop(
            context,
            _AssignResult(
              categoryId: category.value == _keep ? null : category.value,
              typeId: type.value == _keep ? null : type.value,
              unit: unit.value,
              threshold: threshold,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttributeDialog extends HookWidget {
  final Map<String, List<String>> attributeValues;
  final List<int> variantIds;
  final void Function(String message, BulkUndo? undo) onDone;

  const _AttributeDialog({
    required this.attributeValues,
    required this.variantIds,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final attribute = useState(attributeValues.keys.first);
    final valueCtrl = useTextEditingController();
    useListenable(valueCtrl);
    final value = valueCtrl.text.trim();

    final plan = value.isEmpty
        ? null
        : BulkEditService().previewAssign(variantIds, attribute.value, value);

    return AppAlertDialog(
      title: "Đặt giá trị thuộc tính cho biến thể",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Áp cho toàn bộ ${variantIds.length} biến thể của các linh kiện đã chọn.",
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: "Thuộc tính",
            isExpanded: true,
            initialValue: attribute.value,
            items: [
              for (final name in attributeValues.keys)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (v) => attribute.value = v ?? attribute.value,
          ),
          const SizedBox(height: 12),
          AppTextField(label: "Giá trị mới", controller: valueCtrl),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in attributeValues[attribute.value]!)
                ActionChip(label: Text(v), onPressed: () => valueCtrl.text = v),
            ],
          ),
          if (plan != null) ...[
            const SizedBox(height: 12),
            Text(
              "Đổi ${plan.changed} · giữ nguyên ${plan.unchanged}"
              "${plan.skipped > 0 ? " · bỏ qua ${plan.skipped} (không có thuộc tính này)" : ""}",
              style: const TextStyle(fontSize: 12),
            ),
            if (plan.merged > 0)
              Text(
                "⚠ ${plan.merged} biến thể trùng tổ hợp sẽ bị gộp (cộng tồn "
                "kho) và KHÔNG hoàn tác được.",
                style: const TextStyle(color: AppColors.warning, fontSize: 12),
              ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: "Áp dụng",
          size: ButtonSize.small,
          isDisabled: plan == null || plan.changed == 0,
          onPressed: () {
            final r = BulkEditService().assignAttribute(
              variantIds,
              attribute.value,
              value,
            );
            Navigator.pop(context);
            onDone(
              "Đã đặt ${attribute.value} = $value cho ${r.plan.changed} biến thể"
              "${r.plan.merged > 0 ? " (gộp ${r.plan.merged})" : ""}",
              r.undo,
            );
          },
        ),
      ],
    );
  }
}
