import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/constant/app_svgs.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/spec_value.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/util/variant_finder.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Cách sắp xếp kết quả: theo đơn giá, theo giá / 1 đơn vị của thuộc tính
/// số, hoặc theo giá trị thuộc tính.
typedef _Sort = ({String? attribute, bool perUnit});

/// Tìm biến thể của mọi linh kiện theo thông số: thuộc tính số lọc theo
/// khoảng (VD đường kính 18..21mm, dung lượng 2000..3500mAh), thuộc tính chữ
/// chọn giá trị. Kết quả kèm đơn giá rẻ nhất và giá / đơn vị để so chi phí.
/// Trả về id linh kiện được bấm (null = đóng).
class VariantFinderDialog extends HookWidget {
  const VariantFinderDialog({super.key});

  static Future<int?> show(BuildContext context) => showDialog<int>(
    context: context,
    builder: (_) => const VariantFinderDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final db = ObjectboxService.instance;
    final all = useMemoized(
      () =>
          db.get<ComponentVariant>().getAll()
            ..removeWhere((v) => v.component.target == null),
    );
    final types = useMemoized(() => db.get<ComponentType>().getAll());
    final typeById = {for (final t in types) t.id: t};

    final nameCtrl = useTextEditingController();
    useListenable(nameCtrl);
    final typeIds = useState<Set<int>>({});
    final conditions = useState<List<SpecCondition>>([]);
    final pricedOnly = useState(false);
    final inStockOnly = useState(false);
    final sort = useState<_Sort>((attribute: null, perUnit: false));

    // Phạm vi: tên + loại => danh sách thuộc tính để thêm điều kiện
    final query = TextSearch(nameCtrl.text);
    final scope = [
      for (final v in all)
        if ((typeIds.value.isEmpty ||
                typeIds.value.contains(v.component.target!.type.targetId)) &&
            query.matchesWords([v.component.target!.name, v.label]))
          v,
    ];
    final attributes = VariantFinder.attributeValues(scope);
    final numeric = {
      for (final e in attributes.entries)
        e.key: VariantFinder.isNumeric(e.value),
    };
    final units = {
      for (final e in attributes.entries)
        if (numeric[e.key]!) e.key: VariantFinder.commonUnit(e.value),
    };

    final hits = [
      for (final v in scope)
        if (conditions.value.every((c) => VariantFinder.matches(v, c)) &&
            (!inStockOnly.value || (v.stock ?? 0) > 0))
          (variant: v, best: VariantFinder.cheapest(v)),
    ].where((h) => !pricedOnly.value || h.best != null).toList();

    // Giá / 1 đơn vị (VD đ/mAh) theo thuộc tính số [attribute]
    double? perUnit(ComponentVariant v, double? price, String attribute) {
      final unit = units[attribute];
      final raw = VariantFinder.valueOf(v.selection, attribute);
      if (price == null || unit == null || raw == null) return null;
      final amount = VariantFinder.amountIn(raw, unit);
      return amount == null || amount <= 0 ? null : price / amount;
    }

    final s = sort.value;
    int compareNullable(double? a, double? b) => a == null
        ? (b == null ? 0 : 1)
        : b == null
        ? -1
        : a.compareTo(b);
    hits.sort((a, b) {
      if (s.attribute case final attr?) {
        if (s.perUnit) {
          return compareNullable(
            perUnit(a.variant, a.best?.unitPrice, attr),
            perUnit(b.variant, b.best?.unitPrice, attr),
          );
        }
        double? amount(ComponentVariant v) => SpecValue.parse(
          VariantFinder.valueOf(v.selection, attr) ?? "",
        )?.base;
        return compareNullable(amount(a.variant), amount(b.variant));
      }
      return compareNullable(a.best?.unitPrice, b.best?.unitPrice);
    });

    final shownAttributes = [for (final c in conditions.value) c.attribute];
    final numericShown = [
      for (final a in shownAttributes)
        if (numeric[a] == true && units[a] != null) a,
    ];
    final sorts = <(_Sort, String)>[
      ((attribute: null, perUnit: false), "Đơn giá thấp → cao"),
      for (final a in numericShown) ...[
        ((attribute: a, perUnit: true), "Giá / ${units[a]} ($a) thấp → cao"),
        ((attribute: a, perUnit: false), "$a nhỏ → lớn"),
      ],
    ];
    // Bỏ điều kiện => cách sắp xếp theo thuộc tính đó không còn
    if (!sorts.any((e) => e.$1 == s)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => sort.value = (attribute: null, perUnit: false),
      );
    }

    void setCondition(int i, SpecCondition? c) => conditions.value = [
      for (var j = 0; j < conditions.value.length; j++)
        if (j != i) conditions.value[j] else ?c,
    ];

    Widget conditionCard(int i) {
      final c = conditions.value[i];
      final values = attributes[c.attribute] ?? const <String>[];
      final isNumber = numeric[c.attribute] ?? false;
      Widget bound(String label, String value, String hint, bool isMin) =>
          SizedBox(
            width: 100,
            child: TextFormField(
              key: ValueKey(("bound", c.attribute, isMin)),
              initialValue: value,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                isDense: true,
              ),
              onChanged: (t) => setCondition(
                i,
                isMin ? c.copyWith(min: t) : c.copyWith(max: t),
              ),
            ),
          );
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.attribute,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            if (isNumber) ...[
              bound("Từ", c.min, values.first, true),
              const SizedBox(width: 6),
              bound("Đến", c.max, values.last, false),
            ] else
              AppFilterSelect<String>(
                label: "Giá trị",
                icon: Icons.checklist_rounded,
                items: values,
                selected: c.values,
                labelOf: (v) => v,
                onChanged: (set) => setCondition(i, c.copyWith(values: set)),
              ),
            IconButton(
              tooltip: "Bỏ điều kiện",
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setCondition(i, null),
            ),
          ],
        ),
      );
    }

    final unused = [
      for (final a in attributes.keys)
        if (!shownAttributes.any((s) => s.toLowerCase() == a.toLowerCase())) a,
    ];

    Widget cell(String text, double width, {TextStyle? style}) => SizedBox(
      width: width,
      child: Text(
        text,
        style: style ?? const TextStyle(fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    );
    const muted = TextStyle(fontSize: 12, color: AppColors.textMuted);

    Widget header() => Padding(
      padding: const EdgeInsets.fromLTRB(52, 8, 12, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Biến thể",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (final a in shownAttributes)
            cell(a, 90, style: const TextStyle(fontWeight: FontWeight.w600)),
          cell("Kho", 60, style: const TextStyle(fontWeight: FontWeight.w600)),
          cell(
            "Đơn giá rẻ nhất",
            200,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (final a in numericShown)
            cell(
              "đ / ${units[a]}",
              90,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );

    Widget row(
      ({
        ComponentVariant variant,
        ({double unitPrice, ComponentOption option})? best,
      })
      h,
    ) {
      final v = h.variant;
      final component = v.component.target!;
      final best = h.best;
      return InkWell(
        onTap: () => Navigator.pop(context, component.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              ComponentThumbnail.of(component, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      v.label,
                      style: muted,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              for (final a in shownAttributes)
                cell(VariantFinder.valueOf(v.selection, a) ?? "—", 90),
              cell(
                v.stock == null ? "—" : "${v.stock}",
                60,
                style: TextStyle(
                  fontSize: 13,
                  color: (v.stock ?? 1) <= 0 ? AppColors.warning : null,
                ),
              ),
              SizedBox(
                width: 200,
                child: best == null
                    ? const Text("Chưa có giá", style: muted)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.unit.pricePer(best.unitPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            best.option.displayName,
                            style: muted,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
              for (final a in numericShown)
                cell(switch (perUnit(v, best?.unitPrice, a)) {
                  final p? => p.toVND(),
                  null => "—",
                }, 90),
            ],
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Lọc biến thể theo thông số",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: "Đóng",
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Text(
              "Thuộc tính số lọc theo khoảng, hiểu tiền tố đơn vị (VD 2Ah = "
              "2000mAh, 4K7 = 4.7k). Bấm 1 dòng để mở linh kiện.",
              style: muted,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Tên linh kiện / biến thể",
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
                AppFilterSelect<int>(
                  label: "Loại",
                  icon: Icons.memory_outlined,
                  items: [for (final t in types) t.id],
                  selected: typeIds.value,
                  labelOf: (id) => typeById[id]?.name ?? "?",
                  keywordsOf: (id) => typeById[id]?.keywords ?? const [],
                  leadingOf: (id) => AppSvgIcon(
                    svg: typeById[id]?.defaultIconSvg ?? "",
                    fallbackSvg: AppSvgs.chip,
                    size: 18,
                  ),
                  onChanged: (ids) => typeIds.value = ids,
                ),
                FilterChip(
                  label: const Text("Có giá"),
                  selected: pricedOnly.value,
                  onSelected: (v) => pricedOnly.value = v,
                ),
                FilterChip(
                  label: const Text("Còn hàng"),
                  selected: inStockOnly.value,
                  onSelected: (v) => inStockOnly.value = v,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < conditions.value.length; i++)
                  conditionCard(i),
                PopupMenuButton<String>(
                  tooltip: "Lọc theo 1 thuộc tính",
                  enabled: unused.isNotEmpty,
                  onSelected: (a) => conditions.value = [
                    ...conditions.value,
                    SpecCondition(a),
                  ],
                  itemBuilder: (_) => [
                    for (final a in unused)
                      PopupMenuItem(
                        value: a,
                        child: Text(
                          "$a  ·  ${numeric[a]! ? "khoảng số" : "${attributes[a]!.length} giá trị"}",
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: unused.isEmpty
                              ? AppColors.textMuted
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unused.isEmpty
                              ? "Không còn thuộc tính để lọc"
                              : "Thêm điều kiện",
                          style: TextStyle(
                            color: unused.isEmpty
                                ? AppColors.textMuted
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  "${hits.length} biến thể",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const Text("Sắp xếp: ", style: muted),
                DropdownButton<_Sort>(
                  value: sorts.any((e) => e.$1 == s) ? s : sorts.first.$1,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final (value, label) in sorts)
                      DropdownMenuItem(value: value, child: Text(label)),
                  ],
                  onChanged: (v) {
                    if (v != null) sort.value = v;
                  },
                ),
              ],
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    header(),
                    const Divider(height: 1),
                    Expanded(
                      child: hits.isEmpty
                          ? const Center(
                              child: Text(
                                "Không có biến thể khớp",
                                style: muted,
                              ),
                            )
                          : ListView.separated(
                              itemCount: hits.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) => row(hits[i]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
