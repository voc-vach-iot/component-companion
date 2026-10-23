import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/app_setting_repository.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/combo_assistant.dart';
import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/util/component_search.dart';
import 'package:component_companion/widget/ai/ai_ask_panel.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/component/component_option_action.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// [comboCount] = số combo / gói; [mainUnits] và số lượng [extras] tính cho
/// 1 combo.
typedef ImportComboResult = ({
  int comboCount,
  int mainUnits,
  List<ImportComboPart> extras,
});

/// 1 ô thành phần trong dialog (part null = chưa chọn).
typedef _Slot = ({ImportComboPart? part, int quantity});

/// Đánh dấu 1 dòng nhập là combo: 1 gói gồm 1 hay nhiều combo, mỗi combo gồm
/// linh kiện của dòng + các thành phần khác (chọn tay hoặc nhờ AI tách). Thành phần có thể là biến thể có
/// sẵn hoặc biến thể sẽ tạo trong lần nhập này. Trả về extras rỗng = không
/// phải combo, null = huỷ.
class ImportComboDialog extends HookConsumerWidget {
  final ImportPlan plan;

  /// "Tên linh kiện · biến thể" của dòng (linh kiện chính).
  final String mainLabel;

  /// Dòng đã xác định được biến thể của linh kiện chính.
  final bool mainReady;

  /// Biến thể sẽ tạo trong lần nhập (của mọi linh kiện đích).
  final List<ImportComboPart> drafts;

  /// Tạo biến thể mới cho linh kiện của dòng (null = linh kiện không có
  /// thuộc tính).
  final Future<ImportComboPart?> Function()? onNewVariant;

  const ImportComboDialog({
    super.key,
    required this.plan,
    required this.mainLabel,
    this.mainReady = true,
    this.drafts = const [],
    this.onNewVariant,
  });

  static Future<ImportComboResult?> show(
    BuildContext context,
    ImportPlan plan, {
    required String mainLabel,
    bool mainReady = true,
    List<ImportComboPart> drafts = const [],
    Future<ImportComboPart?> Function()? onNewVariant,
  }) => showDialog<ImportComboResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ImportComboDialog(
      plan: plan,
      mainLabel: mainLabel,
      mainReady: mainReady,
      drafts: drafts,
      onNewVariant: onNewVariant,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = plan.row;
    final variants = useState(useMemoized(ComponentOptionAction.allVariants));
    // Biến thể sắp tạo: của lần nhập + đã chọn sẵn + vừa tạo trong dialog
    final newChoices = useState<List<ImportComboPart>>(
      useMemoized(
        () => {
          for (final d in [
            ...drafts,
            ...plan.comboExtras.where((p) => p.isDraft),
          ])
            d.withQuantity(1),
        }.toList(),
      ),
    );
    final items = [
      ...newChoices.value,
      for (final v in variants.value) ImportComboPart.existing(v),
    ];
    final comboCount = useState(plan.combosPerPack);
    // Chưa rõ biến thể => mặc định không gồm linh kiện của dòng
    final mainUnits = useState(
      plan.isCombo ? plan.comboUnits : (mainReady ? 1 : 0),
    );
    final slots = useState<List<_Slot>>([
      for (final p in plan.comboExtras) (part: p, quantity: p.quantity),
      if (plan.comboExtras.isEmpty) (part: null, quantity: 1),
    ]);
    // Đổi số => dựng lại các ô số lượng
    final revision = useState(0);
    final asking = useState(false);
    final aiNote = useState<String?>(null);
    final missing = useState<List<({String name, int quantity})>>(const []);

    final settings = useMemoized(
      () => AiSettings.load(ref.read(appSettingRepositoryProvider)),
    );
    final assistant = useMemoized(
      () => ComboAssistant(
        variants.value,
        newLabels: [for (final d in newChoices.value) d.label],
      ),
    );
    final prompt = useMemoized(
      () => assistant.buildPrompt(
        product: row.name,
        packName: row.packName,
        units: row.units,
        main: mainLabel,
      ),
    );

    void applySuggestion(ComboSuggestion s) {
      asking.value = false;
      aiNote.value = [
        if (!s.isCombo) "AI cho rằng đây không phải combo.",
        if (s.note.isNotEmpty) s.note,
        if (s.model.isNotEmpty) "(${s.model})",
      ].join(" ");
      missing.value = s.missing;
      if (!s.isCombo) return;
      // AI trả số cái cả gói => tách thành số combo × số cái mỗi combo
      final count = [
        s.mainQuantity,
        for (final p in s.parts) p.quantity,
        for (final p in s.newParts) p.quantity,
      ].where((q) => q > 0).fold(0, (g, q) => g.gcd(q));
      final perPack = count > 0 ? count : 1;
      comboCount.value = perPack;
      mainUnits.value = s.mainQuantity ~/ perPack;
      final parts = <_Slot>[
        for (final p in s.parts)
          (
            part: ImportComboPart.existing(p.variant),
            quantity: p.quantity ~/ perPack,
          ),
        for (final p in s.newParts)
          (part: newChoices.value[p.index], quantity: p.quantity ~/ perPack),
      ];
      if (parts.isNotEmpty) slots.value = parts;
      revision.value++;
    }

    void replace(int i, _Slot? slot) => slots.value = [
      for (var j = 0; j < slots.value.length; j++)
        if (j != i) slots.value[j] else ?slot,
    ];

    Future<void> newVariant(int i) async {
      final part = await onNewVariant?.call();
      if (part == null) return;
      if (!newChoices.value.contains(part)) {
        newChoices.value = [...newChoices.value, part];
      }
      replace(i, (part: part, quantity: slots.value[i].quantity));
    }

    final valid = [
      for (final s in slots.value)
        if (s.part != null && s.quantity > 0) s.part!.withQuantity(s.quantity),
    ];

    Widget quantityField(
      int value,
      ValueChanged<int> onChanged,
      Key key, {
      String label = "Cái/combo",
    }) => SizedBox(
      width: 80,
      child: TextFormField(
        key: key,
        initialValue: "$value",
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (t) => onChanged(int.tryParse(t.trim()) ?? 0),
      ),
    );

    // Tổng số cái mỗi thành phần trong 1 gói
    final perPack = [
      if (mainUnits.value > 0)
        "${comboCount.value * mainUnits.value} × $mainLabel",
      for (final p in valid) "${comboCount.value * p.quantity} × ${p.label}",
    ].join(" + ");

    return AppAlertDialog(
      title: "Combo: ${row.name}",
      cancelLabel: "Huỷ thay đổi",
      size: AlertDialogSize.big,
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (row.packName.isNotEmpty) row.packName,
                  if (row.price > 0) "${row.price.toVND()}/gói",
                  if (row.quantity > 0) "mua ${row.quantity} gói",
                ].join(" · "),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Số cái từng thành phần tính cho 1 combo, VD \"10 cặp XT60\" = "
                "10 combo/gói, mỗi combo 1 đực + 1 cái. Giá gói được chia cho "
                "từng thành phần theo giá lẻ tham khảo; nhập kho sẽ cộng đủ mọi "
                "thành phần. Thành phần \"Mới\" là biến thể sẽ được tạo khi nhập.",
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Số combo trong 1 gói",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  quantityField(
                    comboCount.value,
                    (n) => comboCount.value = n,
                    ValueKey(("count", revision.value)),
                    label: "Combo/gói",
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Linh kiện của dòng: $mainLabel",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  quantityField(
                    mainUnits.value,
                    (n) => mainUnits.value = n,
                    ValueKey(("main", revision.value)),
                  ),
                ],
              ),
              if (!mainReady)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    "Dòng chưa chọn biến thể nên để 0 (không gồm). Muốn tính "
                    "linh kiện này vào combo: chọn biến thể ở dòng nhập rồi "
                    "nhập số cái, hoặc thêm biến thể của nó làm thành phần "
                    "bên dưới.",
                    style: TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ),
              const SizedBox(height: 12),
              for (var i = 0; i < slots.value.length; i++)
                Padding(
                  key: ValueKey(("part", i, slots.value.length)),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: AppSearchSelect<ImportComboPart>(
                          label: "Thành phần ${i + 2}",
                          hintText: "Chọn hoặc gõ tên để tạo linh kiện",
                          items: items,
                          value: slots.value[i].part,
                          labelOf: (p) => p.label,
                          keywordsOf: (p) => p.variant == null
                              ? [...p.selection.values]
                              : ComponentSearch.variantKeywords(p.variant!),
                          leadingOf: (p) =>
                              switch (p.variant?.component.target) {
                                final c? => ComponentThumbnail.of(c, size: 28),
                                null => const Icon(
                                  Icons.fiber_new_outlined,
                                  color: AppColors.success,
                                ),
                              },
                          subtitleOf: (p) => switch (p.variant) {
                            null => "Tạo khi nhập",
                            final v =>
                              v.stock == null
                                  ? "Chưa nhập kho"
                                  : "Kho: ${v.stock}",
                          },
                          onChanged: (p) {
                            if (p != null) {
                              replace(i, (
                                part: p,
                                quantity: slots.value[i].quantity,
                              ));
                            }
                          },
                          onCreate: (name) async {
                            final v =
                                await ComponentOptionAction.createPartComponent(
                                  context,
                                  ref,
                                  name,
                                );
                            if (v == null) return;
                            variants.value = [...variants.value, v];
                            replace(i, (
                              part: ImportComboPart.existing(v),
                              quantity: slots.value[i].quantity,
                            ));
                          },
                        ),
                      ),
                      if (onNewVariant != null)
                        IconButton(
                          tooltip:
                              "Biến thể mới của linh kiện dòng này (VD đầu cái)",
                          icon: const Icon(Icons.add_rounded, size: 20),
                          onPressed: () => newVariant(i),
                        ),
                      const SizedBox(width: 8),
                      quantityField(
                        slots.value[i].quantity,
                        (n) => replace(i, (
                          part: slots.value[i].part,
                          quantity: n,
                        )),
                        ValueKey(("qty", i, revision.value)),
                      ),
                      IconButton(
                        tooltip: "Bỏ khỏi combo",
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => replace(i, null),
                      ),
                    ],
                  ),
                ),
              if (valid.isNotEmpty && comboCount.value > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    "1 gói: $perPack",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => slots.value = [
                      ...slots.value,
                      (part: null, quantity: 1),
                    ],
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text("Thêm thành phần"),
                  ),
                  if (!asking.value)
                    TextButton.icon(
                      onPressed: () => asking.value = true,
                      icon: const Icon(Icons.psychology_alt_outlined, size: 18),
                      label: const Text("Nhờ AI tách combo"),
                    ),
                ],
              ),
              if (aiNote.value case final note? when note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    note,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              for (final m in missing.value)
                Text(
                  "AI nêu thêm \"${m.name}\" ×${m.quantity} — kho chưa có, "
                  "gõ tên vào ô thành phần để tạo",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
              if (asking.value) ...[
                const SizedBox(height: 8),
                AiAskPanel<ComboSuggestion>(
                  prompt: prompt,
                  settings: settings,
                  ask: (onTry) => assistant.ask(prompt, settings, onTry: onTry),
                  parse: assistant.parse,
                  onResult: applySuggestion,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (plan.isCombo)
          AppButton(
            label: "Không phải combo",
            size: ButtonSize.small,
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, (
              comboCount: 0,
              mainUnits: 1,
              extras: <ImportComboPart>[],
            )),
          ),
        AppButton(
          label: "Lưu combo",
          size: ButtonSize.small,
          variant: ButtonVariant.primary,
          isDisabled:
              valid.isEmpty || comboCount.value <= 0 || mainUnits.value < 0,
          onPressed: () => Navigator.pop(context, (
            comboCount: comboCount.value,
            mainUnits: mainUnits.value,
            extras: valid,
          )),
        ),
      ],
    );
  }
}
