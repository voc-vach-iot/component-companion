import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/app_setting_repository.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/service/ai/ai_runner.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/place_assistant.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Chọn ngăn cất cho 1 biến thể: gợi ý theo luật, hỏi AI hoặc chọn tay.
class PlacePickerDialog extends HookConsumerWidget {
  final ComponentVariant variant;

  const PlacePickerDialog({super.key, required this.variant});

  /// Mở dialog; trả về true nếu đã đổi chỗ cất.
  static Future<bool> show(
    BuildContext context,
    ComponentVariant variant,
  ) async {
    final storages = StorageRepository().all();
    if (storages.isEmpty) {
      AppSnackBar.show(
        context,
        message: "Chưa có kho nào — tạo kho ở trang Kho trước",
        type: SnackBarType.info,
      );
      return false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (_) => PlacePickerDialog(variant: variant),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(storageRepositoryProvider);
    final storages = useMemoized(repo.all);
    final current = variant.tray.target;
    final storage = useState<Storage>(
      storages.where((s) => s.id == current?.storage.targetId).firstOrNull ??
          storages.first,
    );
    final trays = useMemoized(() => repo.traysOf(storage.value.id), [
      storage.value.id,
    ]);
    final assistant = useMemoized(() => PlaceAssistant(trays), [trays]);
    final ranked = useMemoized(() => assistant.rank(variant).take(5).toList(), [
      assistant,
    ]);
    final tray = useState<StorageTray?>(
      trays.where((t) => t.id == current?.id).firstOrNull,
    );
    final compartment = useState(
      current == null ? 0 : variant.compartmentIndex,
    );
    final aiPick = useState<PlaceSuggestion?>(null);
    final aiStatus = useState<String?>(null);
    final aiSettings = useMemoized(
      () => AiSettings.load(ref.read(appSettingRepositoryProvider)),
    );

    void pick(PlaceSuggestion s) {
      tray.value = s.slot.tray;
      compartment.value = s.slot.compartment;
    }

    Future<void> askAi() async {
      aiStatus.value = "Đang hỏi AI…";
      try {
        final result = await assistant.ask(
          variant,
          aiSettings,
          onTry: (model) => aiStatus.value = "Đang hỏi $model…",
        );
        aiPick.value = result;
        aiStatus.value = null;
        pick(result);
      } on AiFailedException catch (e) {
        aiStatus.value = "AI lỗi:\n${e.summary}";
      } catch (e) {
        aiStatus.value = "AI lỗi: $e";
      }
    }

    Future<void> save(int trayId) async {
      final ok = await repo
          .place(variant.id, trayId, compartmentIndex: compartment.value)
          .then((_) => true)
          .withToast(context);
      if (ok == true && context.mounted) Navigator.pop(context, true);
    }

    Widget suggestionTile(PlaceSuggestion s, {bool ai = false}) {
      final selected =
          tray.value?.id == s.slot.tray.id &&
          compartment.value == s.slot.compartment;
      return Card(
        elevation: 0,
        color: selected ? AppColors.primarySoft : AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: ListTile(
          dense: true,
          onTap: () => pick(s),
          leading: Icon(
            ai ? Icons.auto_awesome_rounded : Icons.lightbulb_outline_rounded,
            color: ai ? AppColors.primary : AppColors.warning,
          ),
          title: Text(
            s.slot.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text([if (ai) "AI (${s.model})", ...s.reasons].join(" · ")),
        ),
      );
    }

    final count = tray.value?.compartmentCount ?? 1;
    return AppAlertDialog(
      title: "Chỗ cất: ${variant.fullLabel}",
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "Đang cất ở: ${variant.placeLabel} (${current.storage.target?.name ?? ""})",
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            if (storages.length > 1) ...[
              AppSearchSelect<Storage>(
                label: "Kho",
                items: storages,
                value: storage.value,
                labelOf: (s) => s.name,
                onChanged: (s) {
                  if (s == null) return;
                  storage.value = s;
                  tray.value = null;
                  aiPick.value = null;
                },
              ),
              const SizedBox(height: 12),
            ],
            if (trays.isEmpty)
              const Text(
                "Kho này chưa có khay nào — thêm khay ở trang Kho.",
                style: TextStyle(color: AppColors.warning),
              )
            else ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Gợi ý",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Tooltip(
                    message: aiSettings.canCallApi
                        ? "Nhờ AI chọn trong các ngăn điểm cao nhất"
                        : "Chưa có API key — cài ở trang Dữ liệu",
                    child: AppButton(
                      label: "Hỏi AI",
                      icon: Icons.auto_awesome_rounded,
                      variant: ButtonVariant.secondary,
                      size: ButtonSize.small,
                      isDisabled:
                          !aiSettings.canCallApi ||
                          (aiStatus.value?.startsWith("Đang") ?? false),
                      onPressed: askAi,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (aiStatus.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    aiStatus.value!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              if (aiPick.value != null) suggestionTile(aiPick.value!, ai: true),
              for (final s in ranked) suggestionTile(s),
              const SizedBox(height: 12),
              AppSearchSelect<StorageTray>(
                label: "Hoặc chọn khay",
                items: trays,
                value: tray.value,
                labelOf: (t) => t.label,
                subtitleOf: (t) =>
                    "${t.trayType.target?.name ?? ""} · "
                    "${t.variants.length} linh kiện"
                    "${t.hasLed ? " · LED ${t.ledIndex + 1}" : " · chưa có LED"}",
                onChanged: (t) {
                  tray.value = t;
                  compartment.value = 0;
                },
              ),
              if (count > 1) ...[
                const SizedBox(height: 12),
                const Text("Ngăn"),
                const SizedBox(height: 6),
                SegmentedButton<int>(
                  segments: [
                    for (var i = 0; i < count; i++)
                      ButtonSegment(value: i, label: Text("Ngăn ${i + 1}")),
                  ],
                  selected: {compartment.value.clamp(0, count - 1)},
                  onSelectionChanged: (v) => compartment.value = v.first,
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (current != null)
          AppButton(
            label: "Bỏ chỗ cất",
            variant: ButtonVariant.danger,
            size: ButtonSize.small,
            onPressed: () => save(0),
          ),
        AppButton(
          label: "Cất vào đây",
          size: ButtonSize.small,
          isDisabled: tray.value == null,
          onPressed: () => save(tray.value!.id),
        ),
      ],
    );
  }
}
