import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/util/bom_parser.dart';
import 'package:component_companion/util/purchase_planner.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/component/component_action.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/project/project_item_action.dart';
import 'package:component_companion/util/component_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 1 dòng BOM đang xem trước: linh kiện / biến thể đoán được, người dùng sửa.
class _Row {
  final BomLine line;
  int? componentId;
  int? variantId;
  int quantity;
  bool include;

  _Row(this.line, {this.componentId, this.variantId})
    : quantity = line.quantity,
      include = componentId != null;
}

/// Dán danh sách linh kiện (BOM) vào phần chung hoặc 1 phương án của dự án.
class BomPasteDialog extends HookConsumerWidget {
  final Project? project;
  final ProjectOption? projectOption;
  final List<Component> availableComponents;

  const BomPasteDialog({
    super.key,
    this.project,
    this.projectOption,
    required this.availableComponents,
  });

  static void show(
    BuildContext context, {
    Project? project,
    ProjectOption? projectOption,
  }) {
    showDialog(
      context: context,
      builder: (_) => ComponentLoader(
        builder: (components) => BomPasteDialog(
          project: project,
          projectOption: projectOption,
          availableComponents: components,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textCtrl = useTextEditingController();
    final rows = useState<List<_Row>>([]);
    final saving = useState(false);
    // Đổi giá trị trong _Row (mutable) => tăng để vẽ lại
    final revision = useState(0);
    void touch() => revision.value++;

    Component? componentOf(_Row r) =>
        availableComponents.where((c) => c.id == r.componentId).firstOrNull;
    ComponentVariant? variantOf(_Row r) {
      final variants = componentOf(r)?.sortedVariants ?? const [];
      // Linh kiện chỉ có 1 biến thể => dùng luôn
      if (r.variantId == null && variants.length == 1) return variants.first;
      return variants.where((v) => v.id == r.variantId).firstOrNull;
    }

    void analyze() {
      rows.value = [
        for (final line in BomParser.parse(textCtrl.text))
          () {
            final component = BomParser.matchComponent(
              line.text,
              availableComponents,
            );
            return _Row(
              line,
              componentId: component?.id,
              variantId: component == null
                  ? null
                  : BomParser.matchVariant(line.text, component)?.id,
            );
          }(),
      ];
    }

    final ready = rows.value
        .where((r) => r.include && variantOf(r) != null && r.quantity > 0)
        .toList();
    final unmatched = rows.value.where((r) => r.componentId == null).length;

    Future<void> import() async {
      if (ready.isEmpty || saving.value) return;
      saving.value = true;
      final items = [
        for (final r in ready)
          () {
            final variant = variantOf(r)!;
            final option = PurchasePlanner.bestSingle(
              variant.options,
              r.quantity,
              variantId: variant.id,
            );
            return ProjectItem(quantity: r.quantity)
              ..component.targetId = r.componentId!
              ..variant.targetId = variant.id
              ..componentOption.targetId = option?.id ?? 0
              ..project.targetId = project?.id ?? 0
              ..projectOption.targetId = projectOption?.id ?? 0;
          }(),
      ];
      final result = await ProjectItemAction.addItems(context, ref, items);
      if (!context.mounted) return;
      saving.value = false;
      if (result == null) return;
      Navigator.of(context).pop();
    }

    Widget rowView(_Row r) {
      final component = componentOf(r);
      final variants = component?.sortedVariants ?? const <ComponentVariant>[];
      final variant = variantOf(r);
      return Container(
        // Giữ đúng ô số lượng khi phân tích lại
        key: ObjectKey(r),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: r.include ? AppColors.surface : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: component == null ? AppColors.warning : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: r.include,
                  onChanged: component == null
                      ? null
                      : (v) {
                          r.include = v ?? false;
                          touch();
                        },
                ),
                Expanded(
                  child: Text(
                    r.line.text,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Text("SL: ", style: TextStyle(fontSize: 12)),
                SizedBox(
                  width: 64,
                  child: TextFormField(
                    initialValue: "${r.quantity}",
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) {
                      r.quantity = int.tryParse(v.trim()) ?? 0;
                      touch();
                    },
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AppSearchSelect<Component>(
                    label: component == null
                        ? "Chưa khớp linh kiện — chọn hoặc gõ tên để tạo"
                        : "Linh kiện",
                    items: availableComponents,
                    value: component,
                    labelOf: (c) => c.name,
                    leadingOf: (c) => ComponentThumbnail.of(c, size: 28),
                    keywordsOf: ComponentSearch.keywords,
                    onChanged: (c) {
                      r
                        ..componentId = c?.id
                        ..variantId = c == null
                            ? null
                            : BomParser.matchVariant(r.line.text, c)?.id
                        ..include = c != null;
                      touch();
                    },
                    onCreate: (name) async {
                      final id = await ComponentAction.showAdd(
                        context,
                        ref,
                        initialName: name.isEmpty ? r.line.text : name,
                      );
                      if (id == null) return;
                      r
                        ..componentId = id
                        ..variantId = null
                        ..include = true;
                      touch();
                    },
                  ),
                ),
                if (component != null && component.hasVariants) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: AppSearchSelect<ComponentVariant>(
                      label: variant == null ? "Chọn biến thể" : "Biến thể",
                      items: variants,
                      value: variant,
                      labelOf: (v) => v.labelFor(component.attributes),
                      onChanged: (v) {
                        r.variantId = v?.id;
                        touch();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return AppAlertDialog(
      title: projectOption == null
          ? "Dán BOM vào linh kiện chung"
          : "Dán BOM vào phương án \"${projectOption!.name}\"",
      size: AlertDialogSize.big,
      content: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: textCtrl,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    "Mỗi dòng 1 linh kiện, VD:\n5x LM358\nĐiện trở 10K 0805 x10\n"
                    "Hoặc dán bảng từ Excel / BOM KiCad (cột số = số lượng)",
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows.value.isEmpty
                        ? "Bấm \"Phân tích\" để khớp với linh kiện có sẵn."
                        : "${rows.value.length} dòng · ${ready.length} sẵn sàng thêm"
                              "${unmatched > 0 ? " · $unmatched chưa khớp (chọn tay hoặc gõ tên để tạo mới)" : ""}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                AppButton(
                  label: "Phân tích",
                  icon: Icons.manage_search_rounded,
                  size: ButtonSize.small,
                  variant: ButtonVariant.secondary,
                  onPressed: analyze,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [for (final r in rows.value) rowView(r)],
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Thêm ${ready.length} linh kiện",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: ready.isEmpty || saving.value,
          onPressed: import,
        ),
      ],
    );
  }
}
