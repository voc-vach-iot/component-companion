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
import 'package:component_companion/util/component_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:component_companion/constant/app_svgs.dart';
import 'package:component_companion/enum/category_color.dart';
import 'package:component_companion/notifier/category_notifier.dart';
import 'package:component_companion/notifier/component_type_notifier.dart';
import 'package:component_companion/widget/ai/ai_catalog_dialog.dart';
import 'package:component_companion/widget/data/import_combo_dialog.dart';
import 'package:component_companion/widget/category/category_action.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:component_companion/widget/component_type/component_type_action.dart';
import 'package:component_companion/widget/icon/icon_picker_dialog.dart';

/// Xem trước trước khi nhập linh kiện từ file / clipboard: mỗi dòng được
/// khớp với linh kiện có sẵn (theo link, tên hoặc đoán) hoặc tạo mới; sửa được
/// linh kiện, biến thể, danh mục / loại.
class ImportDialog extends HookConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Danh mục / loại tạo nhanh trong dialog hiện ngay => đọc từ stream
    final categories =
        ref.watch(watchAllCategoriesProvider()).value ?? this.categories;
    final types =
        ref.watch(watchAllComponentTypesProvider()).value ?? this.types;
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
    final hasSiblings = rows.value.any(
      (p) => rows.value.any(
        (q) =>
            !identical(p, q) &&
            p.row.name.trim().toLowerCase() == q.row.name.trim().toLowerCase(),
      ),
    );
    final guessed = rows.value
        .where((p) => p.existing != null && p.match == ImportMatch.guess)
        .toList();
    final pendingCount = included
        .where(
          (p) => p.row.quantity > 0 && p.row.delivery == ImportDelivery.pending,
        )
        .length;
    final hints = shopHints?.call(rows.value) ?? const <ImportShopHint>[];
    final renames = hints.where((h) => !h.merge).toList();
    final merges = hints.where((h) => h.merge).toList();

    final session = ImportSession(rows.value);
    // Thông báo ngắn sau khi 1 thao tác áp dụng cho nhiều dòng
    final info = useState<String?>(null);
    // Đổi linh kiện ở 1 dòng => đổi cả các dòng cùng sản phẩm
    final syncProduct = useState(true);
    // Trả các dòng cùng sản phẩm về như trước thao tác vừa rồi
    final undoOthers = useState<VoidCallback?>(null);

    void applyTarget(ImportPlan p, int Function(bool sameProduct) action) =>
        edit(() {
          final others = [
            for (final q in session.sameProduct(p))
              if (!identical(q, p)) (q, q.targetState),
          ];
          final n = action(syncProduct.value);
          info.value = n > 1 ? "Đã áp dụng cho $n dòng cùng sản phẩm" : null;
          undoOthers.value = n > 1
              ? () => edit(() {
                  for (final (q, state) in others) {
                    q.restoreTarget(state);
                  }
                  info.value = null;
                  undoOthers.value = null;
                })
              : null;
        });

    void setTarget(ImportPlan p, Component? component, {String? newName}) =>
        applyTarget(
          p,
          (same) => session.setTarget(
            p,
            component,
            newName: newName,
            sameProduct: same,
          ),
        );

    Future<void> newVariant(ImportPlan p) async {
      final selection = await showDialog<VariantSelection>(
        context: context,
        builder: (_) => _VariantValuesDialog(
          title: "Biến thể mới cho ${p.existing?.name ?? p.name}",
          names: session.attributeNames(p),
          known: session.knownValues(p),
          initial: p.attributes,
          allowNewAttribute: p.existing == null,
          packHint: p.row.packName,
        ),
      );
      if (selection == null || selection.isEmpty) return;
      edit(() {
        final filled = session.setVariant(p, selection);
        undoOthers.value = null;
        info.value = filled > 0
            ? "Đã điền biến thể cho $filled dòng khác cùng linh kiện"
            : null;
      });
    }

    final targets = <_Target>[
      for (final name in session.newNames()) _Target.draft(name),
      for (final c in components) _Target.existing(c),
    ];

    Future<void> editCombo(
      ImportPlan p,
      String mainLabel, {
      required bool mainReady,
    }) async {
      final ownKey = session.covers(p)
          ? "${ImportSession.targetKey(p)}|${Variants.key(session.normalized(p))}"
          : null;
      final names = session.attributeNames(p);
      final result = await ImportComboDialog.show(
        context,
        p,
        mainLabel: mainLabel,
        mainReady: mainReady,
        drafts: [
          for (final d in session.comboChoices())
            if (d.key != ownKey &&
                !(d.selection.isEmpty &&
                    d.targetKey == ImportSession.targetKey(p)))
              d,
        ],
        // Biến thể mới của linh kiện dòng này (VD đầu cái của Jack XT60 mới)
        onNewVariant: names.isEmpty && p.existing != null
            ? null
            : () async {
                final selection = await showDialog<VariantSelection>(
                  context: context,
                  builder: (_) => _VariantValuesDialog(
                    title:
                        "Biến thể mới trong combo — ${p.existing?.name ?? p.name}",
                    names: names,
                    known: session.knownValues(p),
                    initial: const {},
                    allowNewAttribute: p.existing == null,
                    packHint: p.row.packName,
                  ),
                );
                if (selection == null || selection.isEmpty) return null;
                final key = Variants.key(selection);
                final existing = p.existing?.variants
                    .where((v) => Variants.key(v.selection) == key)
                    .firstOrNull;
                return existing != null
                    ? ImportComboPart.existing(existing)
                    : ImportComboPart.draft(
                        component: p.existing,
                        newName: p.existing == null ? p.name.trim() : "",
                        selection: selection,
                      );
              },
      );
      if (result == null) return;
      edit(() {
        p
          ..comboExtras = result.extras
          ..comboCount = result.comboCount
          ..comboUnits = result.mainUnits;
      });
    }

    // Combo: tùy chọn cùng link đã là combo / dòng được đánh dấu combo / gợi ý
    Widget comboLine(
      ImportPlan p,
      String? variantLabel, {
      required bool mainReady,
    }) {
      const style = TextStyle(fontSize: 11, color: AppColors.textMuted);
      if (p.linkedOption case final o? when o.isCombo) {
        return Text("Combo có sẵn: ${o.contentsLabel}", style: style);
      }
      if (p.linkedOption != null || !p.row.hasOption) {
        return const SizedBox.shrink();
      }
      final mainLabel = [p.existing?.name ?? p.name, ?variantLabel].join(" · ");
      if (p.isCombo) {
        return Row(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                "Combo: ${p.combosPerPack} combo/gói, mỗi combo "
                "${[if (p.comboUnits > 0) "${p.comboUnits} × $mainLabel", for (final e in p.comboExtras) "${e.quantity} × ${e.label}"].join(" + ")}",
                style: const TextStyle(fontSize: 11, color: AppColors.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => editCombo(p, mainLabel, mainReady: mainReady),
              child: const Text("Sửa", style: TextStyle(fontSize: 11)),
            ),
          ],
        );
      }
      if (!p.row.looksLikeCombo) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: AppColors.warning,
          ),
          onPressed: () => editCombo(p, mainLabel, mainReady: mainReady),
          icon: const Icon(Icons.inventory_2_outlined, size: 14),
          label: const Text(
            "Có vẻ là combo — tách thành phần",
            style: TextStyle(fontSize: 11),
          ),
        ),
      );
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

      final names = session.attributeNames(p);
      final variantChoices = <_VariantChoice>[
        for (final v in component?.sortedVariants ?? const <ComponentVariant>[])
          _VariantChoice(v.id, v.selection, v.labelFor(component!.attributes)),
        for (final s in session.pendingVariants(p))
          _VariantChoice(null, s, "Mới: ${Variants.label(s, null)}"),
      ];
      final ownKey = session.covers(p)
          ? Variants.key(session.normalized(p))
          : null;
      final selectedVariant = variantChoices
          .where(
            (v) => p.variantId != null
                ? v.id == p.variantId
                : v.id == null && Variants.key(v.selection) == ownKey,
          )
          .firstOrNull;
      // Đủ để xác định biến thể của linh kiện dòng (không thuộc tính => mặc định)
      final mainReady =
          selectedVariant != null ||
          (component == null ? names.isEmpty : !component.hasVariants);
      final keepsOptionVariants =
          linked != null && p.attributes.isEmpty && p.variantId == null;
      final variantLabel =
          selectedVariant?.label ??
          (keepsOptionVariants
              ? "Giữ biến thể của tùy chọn"
              : component != null
              ? "Chưa chọn — áp cho mọi biến thể khớp"
              : names.isEmpty
              ? "Không có biến thể — bấm + để thêm thuộc tính"
              : "Chưa đủ thuộc tính — bấm + để điền");
      final sameProductCount = session.sameProduct(p).length;

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
                        if (linked == null && row.hasOption && !p.isCombo)
                          IconButton(
                            tooltip: "Đánh dấu là combo nhiều linh kiện",
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            icon: const Icon(Icons.inventory_2_outlined),
                            onPressed: () => editCombo(
                              p,
                              [
                                component?.name ?? p.name,
                                ?selectedVariant?.label,
                              ].join(" · "),
                              mainReady: mainReady,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      [
                        if (row.shopName.isNotEmpty) row.shopName,
                        if (row.attributes.isNotEmpty) row.attributesLabel,
                        if (row.packName.isNotEmpty) row.packName,
                        if (row.price > 0)
                          p.isCombo || (linked?.isCombo ?? false)
                              ? "$priceChange${row.price.toVND()}/combo"
                              : "$priceChange${row.price.toVND()}/${row.units} cái",
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
                          child: _CompactSelect<_Target>(
                            icon: component == null
                                ? Icons.fiber_new_outlined
                                : Icons.inventory_2_outlined,
                            label: component?.name ?? "Tạo mới: ${p.name}",
                            items: targets,
                            selected: component == null
                                ? _Target.draft(p.name)
                                : _Target.existing(component),
                            labelOf: (t) => t.label,
                            leadingOf: (t) => t.component == null
                                ? const Icon(
                                    Icons.fiber_new_outlined,
                                    color: AppColors.success,
                                  )
                                : ComponentThumbnail.of(t.component!, size: 28),
                            keywordsOf: (t) => t.component == null
                                ? const []
                                : ComponentSearch.keywords(t.component!),
                            noneLabel: "Tạo linh kiện mới (tên gốc)",
                            onCreate: (name) =>
                                setTarget(p, null, newName: name),
                            onChanged: (t) => t == null
                                ? setTarget(p, null)
                                : setTarget(p, t.component, newName: t.newName),
                          ),
                        ),
                        // Chuyển nhanh: tạo mới <-> gợi ý ban đầu
                        if (component != null)
                          Tooltip(
                            message:
                                "Không thêm vào \"${component.name}\" — tạo linh kiện mới tên \"${row.name}\"",
                            child: TextButton.icon(
                              onPressed: () => setTarget(p, null),
                              icon: const Icon(
                                Icons.add_box_outlined,
                                size: 16,
                              ),
                              label: const Text("Tạo mới"),
                            ),
                          )
                        else if (p.suggested case final s?)
                          Tooltip(
                            message: "Thêm vào linh kiện có sẵn \"${s.name}\"",
                            child: TextButton.icon(
                              onPressed: () => applyTarget(
                                p,
                                (same) =>
                                    session.useSuggestion(p, sameProduct: same),
                              ),
                              icon: const Icon(Icons.link_rounded, size: 16),
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                child: Text(
                                  "Dùng: ${s.name}",
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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
                              keywordsOf: (id) =>
                                  categoryById[id]?.keywords ?? const [],
                              onChanged: (id) => edit(
                                () => session.setNewDetails(
                                  p,
                                  categoryId: id ?? 0,
                                ),
                              ),
                              // Không thấy => tạo nhanh, tạo xong chọn luôn
                              onCreate: (name) => CategoryAction.showAdd(
                                context,
                                ref,
                                initial: Category(
                                  name: name,
                                  colorValue: CategoryColor.values.first.color
                                      .toARGB32(),
                                ),
                                onSuccess: (id) => edit(
                                  () =>
                                      session.setNewDetails(p, categoryId: id),
                                ),
                              ),
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
                              keywordsOf: (id) =>
                                  typeById[id]?.keywords ?? const [],
                              onChanged: (id) => edit(() {
                                // Chưa có danh mục thì lấy theo loại
                                final suggested =
                                    typeById[id]?.category.targetId ?? 0;
                                session.setNewDetails(
                                  p,
                                  typeId: id ?? 0,
                                  categoryId:
                                      p.categoryId == 0 && suggested != 0
                                      ? suggested
                                      : null,
                                );
                              }),
                              onCreate: (name) => ComponentTypeAction.showAdd(
                                context,
                                ref,
                                initial: ComponentType(name: name)
                                  ..category.targetId = p.categoryId,
                                onSuccess: (id) => edit(
                                  () => session.setNewDetails(p, typeId: id),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: "Nhờ AI gợi ý danh mục / loại",
                            icon: const Icon(
                              Icons.psychology_alt_outlined,
                              size: 20,
                            ),
                            onPressed: () async {
                              final ids = await AiCatalogDialog.show(
                                context,
                                name: p.name,
                                attributes: session.attributeNames(p),
                                categories: categories,
                                types: types,
                              );
                              if (ids == null) return;
                              edit(
                                () => session.setNewDetails(
                                  p,
                                  categoryId: ids.categoryId > 0
                                      ? ids.categoryId
                                      : null,
                                  typeId: ids.typeId > 0 ? ids.typeId : null,
                                ),
                              );
                            },
                          ),
                          // Icon riêng của linh kiện mới (thư viện / dán / AI vẽ)
                          Tooltip(
                            message: p.iconSvg.isEmpty
                                ? "Chọn icon (mặc định dùng icon của loại)"
                                : "Đổi icon",
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                final svg = await showIconPicker(
                                  context,
                                  currentSvg: p.iconSvg,
                                  initialQuery: p.name,
                                );
                                if (svg != null) {
                                  edit(
                                    () =>
                                        session.setNewDetails(p, iconSvg: svg),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: AppSvgIcon(
                                  svg: p.iconSvg.isNotEmpty
                                      ? p.iconSvg
                                      : typeById[p.typeId]?.defaultIconSvg ??
                                            "",
                                  fallbackSvg: AppSvgs.chip,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Biến thể: có sẵn + sẽ tạo theo các dòng cùng linh kiện
                    if (component == null || component.hasVariants)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: _CompactSelect<_VariantChoice>(
                                icon: Icons.tune_rounded,
                                label: variantLabel,
                                warning:
                                    selectedVariant == null &&
                                    !keepsOptionVariants &&
                                    (component != null || names.isNotEmpty),
                                items: variantChoices,
                                selected: selectedVariant,
                                labelOf: (v) => v.label,
                                onChanged: (v) => edit(() {
                                  if (v == null) return;
                                  if (v.id != null) {
                                    session.chooseVariant(p, v.id!);
                                  } else {
                                    session.choosePending(p, v.selection);
                                  }
                                }),
                              ),
                            ),
                            IconButton(
                              tooltip: component == null && names.isEmpty
                                  ? "Thêm thuộc tính / biến thể"
                                  : "Biến thể mới",
                              icon: const Icon(Icons.add_rounded, size: 20),
                              onPressed: () => newVariant(p),
                            ),
                          ],
                        ),
                      ),
                    comboLine(p, selectedVariant?.label, mainReady: mainReady),
                    if (sameProductCount > 1)
                      Text(
                        syncProduct.value
                            ? "Cùng sản phẩm với ${sameProductCount - 1} dòng "
                                  "khác — đổi linh kiện ở đây sẽ áp dụng cho cả "
                                  "các dòng đó"
                            : "Cùng sản phẩm với ${sameProductCount - 1} dòng "
                                  "khác — đang đổi riêng từng dòng",
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
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
            if (info.value != null)
              Row(
                children: [
                  Flexible(
                    child: Text(
                      info.value!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (undoOthers.value case final undo?)
                    TextButton(
                      onPressed: undo,
                      child: const Text(
                        "Chỉ đổi dòng này",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            if (hasSiblings)
              Row(
                children: [
                  Checkbox(
                    value: syncProduct.value,
                    onChanged: (v) => syncProduct.value = v ?? false,
                  ),
                  const Flexible(
                    child: Text(
                      "Đổi linh kiện ở 1 dòng thì đổi luôn các dòng cùng sản "
                      "phẩm (bỏ chọn nếu mỗi phân loại là 1 linh kiện khác nhau)",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
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
                if (guessed.isNotEmpty)
                  Tooltip(
                    message:
                        "Các dòng chỉ được đoán theo tên sẽ tạo linh kiện mới",
                    child: TextButton(
                      onPressed: () => edit(() {
                        for (final p in guessed) {
                          p.createNew();
                        }
                      }),
                      child: Text("Bỏ ${guessed.length} khớp đoán"),
                    ),
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

/// Linh kiện đích trong ô chọn: có sẵn hoặc sẽ tạo mới (theo tên).
class _Target {
  final Component? component;
  final String? newName;

  _Target.existing(Component this.component) : newName = null;
  _Target.draft(String this.newName) : component = null;

  String get key => component != null
      ? "#${component!.id}"
      : "new:${newName!.trim().toLowerCase()}";

  String get label => component?.name ?? "Mới: $newName";

  @override
  bool operator ==(Object other) => other is _Target && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Biến thể trong ô chọn: có sẵn ([id]) hoặc sẽ tạo theo dòng khác.
class _VariantChoice {
  final int? id;
  final VariantSelection selection;
  final String label;

  const _VariantChoice(this.id, this.selection, this.label);

  String get key => id != null ? "#$id" : Variants.key(selection);

  @override
  bool operator ==(Object other) => other is _VariantChoice && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Nhập giá trị từng thuộc tính cho biến thể mới. Linh kiện sẽ tạo mới được
/// thêm thuộc tính mới.
class _VariantValuesDialog extends HookWidget {
  final String title;
  final List<String> names;
  final Map<String, List<String>> known;
  final VariantSelection initial;
  final bool allowNewAttribute;

  /// Phân loại của dòng — gợi ý giá trị khi chưa có thuộc tính nào.
  final String packHint;

  const _VariantValuesDialog({
    required this.title,
    required this.names,
    required this.known,
    required this.initial,
    required this.allowNewAttribute,
    required this.packHint,
  });

  @override
  Widget build(BuildContext context) {
    String? initialOf(String name) => initial.entries
        .where((e) => e.key.toLowerCase() == name.toLowerCase())
        .firstOrNull
        ?.value;
    final controllers = [
      for (final n in names) useTextEditingController(text: initialOf(n)),
    ];
    final addingNew = useState(names.isEmpty);
    final newName = useTextEditingController();
    final newValue = useTextEditingController(
      text: names.isEmpty ? packHint : "",
    );
    // Vẽ lại để bật / tắt nút khi gõ
    useListenable(Listenable.merge([...controllers, newName, newValue]));
    final newOk =
        !addingNew.value ||
        (newName.text.trim().isEmpty && newValue.text.trim().isEmpty) ||
        (newName.text.trim().isNotEmpty && newValue.text.trim().isNotEmpty);
    final hasNew =
        addingNew.value &&
        newName.text.trim().isNotEmpty &&
        newValue.text.trim().isNotEmpty;
    final complete =
        controllers.every((c) => c.text.trim().isNotEmpty) &&
        newOk &&
        (names.isNotEmpty || hasNew);

    return AppAlertDialog(
      title: title,
      size: AlertDialogSize.small,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < names.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: controllers[i],
                autofocus: i == 0,
                decoration: InputDecoration(
                  labelText: names[i],
                  helperText: (known[names[i]] ?? const []).isEmpty
                      ? null
                      : "Đã có: ${known[names[i]]!.join(", ")}",
                ),
              ),
            ),
          if (allowNewAttribute && addingNew.value)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newName,
                    autofocus: names.isEmpty,
                    decoration: const InputDecoration(
                      labelText: "Thuộc tính mới",
                      hintText: "VD Dung lượng",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: newValue,
                    decoration: const InputDecoration(
                      labelText: "Giá trị",
                      hintText: "VD 16GB",
                    ),
                  ),
                ),
              ],
            )
          else if (allowNewAttribute)
            TextButton.icon(
              onPressed: () => addingNew.value = true,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text("Thêm thuộc tính"),
            ),
          const SizedBox(height: 8),
          const Text(
            "Các dòng khác cùng linh kiện sẽ được điền theo cùng cột "
            "(VD điền 16GB từ Phân loại => dòng khác lấy 32GB, 64GB...).",
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
            for (var i = 0; i < names.length; i++)
              names[i]: controllers[i].text.trim(),
            if (hasNew) newName.text.trim(): newValue.text.trim(),
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
  final List<String> Function(T item)? keywordsOf;
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
    this.keywordsOf,
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
        keywordsOf: keywordsOf,
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
