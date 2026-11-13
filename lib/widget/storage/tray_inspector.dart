import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/notifier/led_notifier.dart';
import 'package:component_companion/service/led/locate_planner.dart';
import 'package:component_companion/util/compartments.dart';
import 'package:component_companion/util/led_plan.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/storage/ble_pair_dialog.dart';
import 'package:component_companion/widget/storage/led_color_picker.dart';
import 'package:component_companion/widget/storage/led_number_dialog.dart';
import 'package:component_companion/widget/storage/led_shift_dialog.dart';
import 'package:component_companion/widget/storage/storage_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Panel bên phải trang Kho: thông tin kho (chưa chọn khay), chi tiết 1 khay
/// hoặc thao tác với nhiều khay.
class TrayInspector extends ConsumerWidget {
  final Storage storage;
  final List<StorageTray> trays;
  final List<TrayType> trayTypes;
  final Set<int> selected;
  final ValueChanged<Set<int>> onSelect;

  const TrayInspector({
    super.key,
    required this.storage,
    required this.trays,
    required this.trayTypes,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = trays.where((t) => selected.contains(t.id)).toList();
    final Widget child;
    if (picked.isEmpty) {
      child = _StorageSummary(storage: storage, trays: trays);
    } else if (picked.length == 1) {
      child = _TrayDetail(
        key: ValueKey(picked.single.id),
        storage: storage,
        tray: picked.single,
        trayTypes: trayTypes,
        onSelect: onSelect,
      );
    } else {
      child = _MultiSelection(
        storage: storage,
        trays: picked,
        onSelect: onSelect,
      );
    }
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

const _title = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
const _muted = TextStyle(fontSize: 12, color: AppColors.textMuted);

class _StorageSummary extends ConsumerWidget {
  final Storage storage;
  final List<StorageTray> trays;

  const _StorageSummary({required this.storage, required this.trays});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supply = storage.powerSupply.target;
    final budget = LedPowerSpec(
      supplyCurrentA: supply?.currentA ?? 1,
      derate: supply?.derate ?? 0.8,
      ledCount: storage.ledCount,
      mAPerChannel: storage.mAPerChannel,
      idleMaPerLed: storage.idleMaPerLed,
      mcuMa: storage.mcuMa,
    ).budgetMa;
    final withLed = trays.where((t) => t.hasLed).length;
    final items = trays.fold(0, (sum, t) => sum + t.variants.length);
    final fullAtOnce = (budget / storage.mAPerChannel).floor();

    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: _muted)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(storage.name, style: _title),
        const SizedBox(height: 4),
        Text(
          "${storage.widthMm.round()} × ${storage.heightMm.round()} mm",
          style: _muted,
        ),
        const Divider(height: 20),
        row("Khay", "${trays.length}"),
        row("Linh kiện đã cất", "$items"),
        row(
          "LED đã gắn",
          "$withLed / ${storage.ledCount}",
          color: withLed < trays.length ? AppColors.warning : null,
        ),
        row(
          "Nguồn",
          supply == null ? "chưa chọn (tính 1A)" : supply.spec,
          color: supply == null ? AppColors.warning : null,
        ),
        row("Dòng cho LED sáng", "${budget.round()} mA"),
        row("Sáng 1 kênh tối đa cùng lúc", "$fullAtOnce LED"),
        row("Tự tắt sau", "${storage.lightTimeoutS} giây"),
        row(
          "Bộ điều khiển",
          storage.bleDeviceId.isEmpty ? "giả lập" : storage.bleName,
          color: storage.bleDeviceId.isEmpty ? AppColors.textMuted : null,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: "Chèn / dời số LED…",
          icon: Icons.swap_horiz_rounded,
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
          onPressed: () => showLedShiftDialog(context, ref, storage),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: storage.bleDeviceId.isEmpty ? "Ghép BLE" : "Đổi BLE",
                icon: Icons.bluetooth_searching_rounded,
                variant: ButtonVariant.secondary,
                size: ButtonSize.small,
                onPressed: () => BlePairDialog.show(context, storage),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: "Thử kết nối",
                icon: Icons.wifi_tethering_rounded,
                variant: ButtonVariant.secondary,
                size: ButtonSize.small,
                isDisabled: storage.bleDeviceId.isEmpty,
                onPressed: () => pingController(context, ref, storage),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          "Kéo loại khay từ cột trái vào sơ đồ để thêm khay. Kéo linh kiện "
          "\"chưa có chỗ\" thả vào ngăn để cất. Giữ Shift / Ctrl để chọn nhiều "
          "khay.",
          style: _muted,
        ),
      ],
    );
  }
}

class _MultiSelection extends ConsumerWidget {
  final Storage storage;
  final List<StorageTray> trays;
  final ValueChanged<Set<int>> onSelect;

  const _MultiSelection({
    required this.storage,
    required this.trays,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(storageRepositoryProvider);
    final ids = trays.map((t) => t.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Đã chọn ${trays.length} khay", style: _title),
        const SizedBox(height: 4),
        Text(trays.map((t) => t.label).join(", "), style: _muted),
        const SizedBox(height: 14),
        AppButton(
          label: "Sáng các khay này",
          icon: Icons.lightbulb_outline_rounded,
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
          onPressed: () => lightTrays(context, ref, storage, trays),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: "Đánh số LED cho vùng chọn…",
          icon: Icons.pin_outlined,
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
          onPressed: () => showLedNumberDialog(
            context,
            ref,
            storage,
            trays,
            repo.traysOf(storage.id),
          ),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: "Nhân bản",
          icon: Icons.copy_rounded,
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
          onPressed: () async {
            final union = trays
                .map((t) => (left: t.xMm, right: t.xMm + t.frontWidthMm))
                .reduce(
                  (a, b) => (
                    left: a.left < b.left ? a.left : b.left,
                    right: a.right > b.right ? a.right : b.right,
                  ),
                );
            final created = await repo
                .duplicateTrays(ids, dx: union.right - union.left)
                .withToast(context);
            if (created != null) onSelect(created.toSet());
          },
        ),
        const SizedBox(height: 8),
        AppButton(
          label: "Xoá ${trays.length} khay",
          icon: Icons.delete_outline,
          variant: ButtonVariant.danger,
          size: ButtonSize.small,
          onPressed: () async {
            await StorageAction.deleteTrays(context, ref, ids);
            onSelect({});
          },
        ),
      ],
    );
  }
}

/// Sáng các khay theo màu mặc định của loại khay (thử LED).
Future<void> lightTrays(
  BuildContext context,
  WidgetRef ref,
  Storage storage,
  List<StorageTray> trays,
) async {
  final withLed = trays.where((t) => t.hasLed).toList();
  if (withLed.isEmpty) return;
  final requests = <LedRequest>[];
  final colors = <int, int>{};
  final labels = <int, List<String>>{};
  for (final t in withLed) {
    final type = t.trayType.target;
    final color = type?.defaultColor ?? 0xFFFFFFFF;
    requests.add(
      LedRequest(
        ledIndex: t.ledIndex,
        color: color,
        brightness: type?.maxBrightness ?? 255,
        minBrightness: type?.minBrightness ?? 0,
      ),
    );
    colors[t.id] = color;
    labels[t.ledIndex] = [t.label];
  }
  await ref
      .read(ledSessionsProvider.notifier)
      .lightRaw(storage, requests, labels: labels, trayColors: colors)
      .withToast(context);
}

class _TrayDetail extends HookConsumerWidget {
  final Storage storage;
  final StorageTray tray;
  final List<TrayType> trayTypes;
  final ValueChanged<Set<int>> onSelect;

  const _TrayDetail({
    super.key,
    required this.storage,
    required this.tray,
    required this.trayTypes,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(storageRepositoryProvider);
    final label = useTextEditingController(text: tray.label);
    final led = useTextEditingController(
      text: tray.hasLed ? "${tray.ledIndex + 1}" : "",
    );
    useEffect(() {
      label.text = tray.label;
      led.text = tray.hasLed ? "${tray.ledIndex + 1}" : "";
      return null;
    }, [tray.label, tray.ledIndex]);
    final type = tray.trayType.target;
    final contents = repo.contentsOf(tray.id);

    Future<void> update(void Function(StorageTray t) change) async {
      final next = repo.tray(tray.id);
      if (next == null) return;
      change(next);
      await repo.updateTray(next).withToast(context);
    }

    Future<void> saveLed() async {
      final text = led.text.trim();
      final index = text.isEmpty ? -1 : (int.tryParse(text) ?? 0) - 1;
      if (text.isNotEmpty && index < 0) return;
      await repo.setLed(tray.id, index).withToast(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(tray.label, style: _title)),
            IconButton(
              tooltip: "Bỏ chọn",
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => onSelect({}),
            ),
          ],
        ),
        if (type != null)
          Text(
            "${type.name} · ${type.widthMm.round()}×${type.depthMm.round()}×"
            "${type.heightMm.round()} mm · ${tray.compartmentCount} ngăn"
            "${type.removableDividers ? " (vách tháo được)" : ""}",
            style: _muted,
          ),
        const SizedBox(height: 12),
        TextField(
          controller: label,
          decoration: const InputDecoration(
            labelText: "Tên khay",
            helperText: "Enter để lưu",
            isDense: true,
          ),
          onSubmitted: (v) => update((t) => t.label = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: tray.trayType.targetId,
          isDense: true,
          decoration: const InputDecoration(labelText: "Loại khay"),
          items: [
            for (final t in trayTypes)
              DropdownMenuItem(value: t.id, child: Text(t.name)),
          ],
          onChanged: (id) {
            if (id != null) update((t) => t.trayType.targetId = id);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text("Xoay 90°"),
          subtitle: const Text("Mặt trước là cạnh sâu"),
          value: tray.rotated,
          onChanged: (v) => update((t) => t.rotated = v),
        ),
        if (type != null &&
            type.removableDividers &&
            type.compartmentCount > 1 &&
            type.compartmentCount <= 4) ...[
          const SizedBox(height: 4),
          const Text("Vách ngăn", style: _muted),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in Compartments.allLayouts(type.compartmentCount))
                _LayoutChip(
                  sizes: Compartments.sizes(type.compartmentCount, m),
                  label: Compartments.describe(type.compartmentCount, m),
                  vertical: type.compartmentVertical,
                  selected: tray.removedDividers == m,
                  onTap: () =>
                      repo.setRemovedDividers(tray.id, m).withToast(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: led,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "LED số (1–${storage.ledCount})",
                  helperText: "Trống = chưa gắn LED",
                  isDense: true,
                ),
                onSubmitted: (_) => saveLed(),
              ),
            ),
            IconButton(
              tooltip: "Lưu LED",
              icon: const Icon(Icons.check_rounded),
              onPressed: saveLed,
            ),
            IconButton(
              tooltip: "Sáng khay này",
              icon: const Icon(Icons.lightbulb_outline_rounded),
              onPressed: tray.hasLed
                  ? () => lightTrays(context, ref, storage, [tray])
                  : null,
            ),
          ],
        ),
        const Divider(height: 24),
        for (var i = 0; i < tray.compartmentCount; i++)
          _CompartmentSection(
            storage: storage,
            tray: tray,
            index: i,
            items: contents[i] ?? const [],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: "Nhân bản",
                icon: Icons.copy_rounded,
                variant: ButtonVariant.secondary,
                size: ButtonSize.small,
                onPressed: () async {
                  final created = await repo
                      .duplicateTrays([tray.id], dx: tray.frontWidthMm)
                      .withToast(context);
                  if (created != null) onSelect(created.toSet());
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: "Xoá",
                icon: Icons.delete_outline,
                variant: ButtonVariant.danger,
                size: ButtonSize.small,
                onPressed: () async {
                  await StorageAction.deleteTrays(context, ref, [tray.id]);
                  onSelect({});
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompartmentSection extends ConsumerWidget {
  final Storage storage;
  final StorageTray tray;
  final int index;
  final List<ComponentVariant> items;

  const _CompartmentSection({
    required this.storage,
    required this.tray,
    required this.index,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(storageRepositoryProvider);
    return DragTarget<ComponentVariant>(
      onAcceptWithDetails: (d) => repo
          .place(d.data.id, tray.id, compartmentIndex: index)
          .withToast(context),
      builder: (context, candidates, _) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? AppColors.primarySoft
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tray.compartmentCount > 1
                        ? "Ngăn ${index + 1}"
                        : "Linh kiện",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (items.isNotEmpty)
                  IconButton(
                    tooltip: "Chuyển ngăn sang khay khác…",
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.drive_file_move_outline, size: 18),
                    onPressed: () => StorageAction.pickAndMoveCompartment(
                      context,
                      ref,
                      tray,
                      index,
                    ),
                  ),
                IconButton(
                  tooltip: "Thêm linh kiện vào đây",
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () async {
                    final v = await _pickVariant(context, repo);
                    if (v == null || !context.mounted) return;
                    await repo
                        .place(v.id, tray.id, compartmentIndex: index)
                        .withToast(context);
                  },
                ),
              ],
            ),
            if (items.isEmpty)
              const Text("Trống", style: _muted)
            else
              for (final v in items)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        v.fullLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (v.stock != null) Text("${v.stock}", style: _muted),
                    IconButton(
                      tooltip: "Tìm (sáng LED)",
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 16,
                      ),
                      onPressed: tray.hasLed
                          ? () => ref
                                .read(ledSessionsProvider.notifier)
                                .locate([LocateTarget(v)])
                                .withToast(context)
                          : null,
                    ),
                    IconButton(
                      tooltip: "Bỏ khỏi ngăn",
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => repo.place(v.id, 0).withToast(context),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  static Future<ComponentVariant?> _pickVariant(
    BuildContext context,
    StorageRepository repo,
  ) {
    final unplaced = repo.unplaced();
    ComponentVariant? picked;
    return showDialog<ComponentVariant>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AppAlertDialog(
          title: "Thêm linh kiện vào ngăn",
          content: AppSearchSelect<ComponentVariant>(
            label: "Linh kiện chưa có chỗ",
            items: unplaced,
            value: picked,
            labelOf: (v) => v.fullLabel,
            subtitleOf: (v) => v.stock == null ? null : "Còn ${v.stock}",
            onChanged: (v) => setState(() => picked = v),
          ),
          actions: [
            AppButton(
              label: "Thêm",
              size: ButtonSize.small,
              isDisabled: picked == null,
              onPressed: () => Navigator.pop(ctx, picked),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1 cách chia ngăn: hình thu nhỏ các ngăn + mô tả.
class _LayoutChip extends StatelessWidget {
  final List<int> sizes;
  final String label;
  final bool vertical;
  final bool selected;
  final VoidCallback onTap;

  const _LayoutChip({
    required this.sizes,
    required this.label,
    required this.vertical,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.borderStrong;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 22,
              child: Flex(
                direction: vertical ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in sizes)
                    Expanded(
                      flex: s,
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          border: Border.all(color: color),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Màu hiển thị nhỏ cạnh tên loại khay.
class TrayTypeSwatch extends StatelessWidget {
  final TrayType type;

  const TrayTypeSwatch({super.key, required this.type});

  @override
  Widget build(BuildContext context) =>
      LedColorDot(color: type.defaultColor, size: 14);
}
