import 'dart:async';
import 'dart:math' as math;

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/notifier/led_notifier.dart';
import 'package:component_companion/notifier/storage_notifier.dart';
import 'package:component_companion/notifier/storage_undo_notifier.dart';
import 'package:component_companion/util/led_order.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/storage/led_color_picker.dart';
import 'package:component_companion/widget/storage/led_number_dialog.dart';
import 'package:component_companion/widget/storage/led_shift_dialog.dart';
import 'package:component_companion/widget/storage/place_picker_dialog.dart';
import 'package:component_companion/widget/storage/storage_action.dart';
import 'package:component_companion/widget/storage/storage_canvas.dart';
import 'package:component_companion/widget/storage/tray_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Kho thông minh: sơ đồ khay kéo thả, loại khay, nguồn cấp cho dải LED.
class StoragePage extends HookConsumerWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = useTabController(initialLength: 3);
    ref.listen(storageFocusProvider, (_, next) {
      if (next != null) tabs.animateTo(0);
    });
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Kho thông minh".toUpperCase(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          TabBar(
            controller: tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: "Sơ đồ kho"),
              Tab(text: "Loại khay"),
              Tab(text: "Nguồn"),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: tabs,
              physics: const NeverScrollableScrollPhysics(),
              children: const [_MapTab(), _TrayTypesTab(), _SuppliesTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SƠ ĐỒ KHO
// =============================================================================

class _MapTab extends HookConsumerWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final storagesAsync = ref.watch(watchAllStoragesProvider);
    final selectedStorage = useState<int?>(
      ref.read(storageFocusProvider)?.storageId,
    );
    ref.listen(storageFocusProvider, (_, next) {
      if (next != null) selectedStorage.value = next.storageId;
    });

    return storagesAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, _) => AppErrorView(message: "Lỗi tải kho: $e"),
      data: (storages) {
        if (storages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Chưa có kho nào"),
                const SizedBox(height: 12),
                AppButton(
                  label: "Thêm kho",
                  icon: Icons.add_rounded,
                  onPressed: () => StorageAction.showStorage(context, ref),
                ),
              ],
            ),
          );
        }
        final storage =
            storages.where((s) => s.id == selectedStorage.value).firstOrNull ??
            storages.first;
        return _StorageEditor(
          key: ValueKey(storage.id),
          storage: storage,
          storages: storages,
          onStorageChanged: (id) => selectedStorage.value = id,
        );
      },
    );
  }
}

class _StorageEditor extends HookConsumerWidget {
  final Storage storage;
  final List<Storage> storages;
  final ValueChanged<int> onStorageChanged;

  const _StorageEditor({
    super.key,
    required this.storage,
    required this.storages,
    required this.onStorageChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(storageRepositoryProvider);
    final traysAsync = ref.watch(watchStorageTraysProvider(storage.id));
    final trayTypes =
        ref.watch(watchAllTrayTypesProvider).value ?? const <TrayType>[];
    final session = ref.watch(ledSessionsProvider.select((s) => s[storage.id]));
    final selected = useState<Set<int>>({});
    final mode = useState(CanvasMode.arrange);
    final zoom = useState(1.0);
    final wireNext = useState(0);
    // null = theo chế độ (bật ở "nối dây LED", tắt ở "sắp xếp")
    final wireOverride = useState<bool?>(null);
    final fitSignal = useState(0);
    final showWire = wireOverride.value ?? (mode.value == CanvasMode.wire);
    final focus = useFocusNode();

    final trays = traysAsync.value ?? const <StorageTray>[];
    // Bỏ chọn khay đã bị xoá
    final ids = trays.map((t) => t.id).toSet();
    if (selected.value.any((id) => !ids.contains(id))) {
      final kept = selected.value.where(ids.contains).toSet();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => selected.value = kept,
      );
    }

    Future<void> addTray(TrayType type, [Offset? at]) async {
      final probe = StorageTray()..trayType.target = type;
      var pos =
          at ??
          findFreeSpot(storage, trays, probe.frontWidthMm, probe.frontHeightMm);
      if (at != null) {
        // Thả theo tâm con trỏ, bắt dính lưới
        final g = storage.gridMm;
        pos = Offset(
          ((pos.dx - probe.frontWidthMm / 2) / g).round() * g,
          ((pos.dy - probe.frontHeightMm / 2) / g).round() * g,
        );
      }
      final id = await repo
          .addTray(storage.id, type.id, xMm: pos.dx, yMm: pos.dy)
          .withToast(context);
      if (id != null) selected.value = {id};
    }

    // Lưu vị trí cũ để hoàn tác di chuyển
    void pushMoveUndo(Iterable<int> movedIds) {
      final old = {
        for (final t in trays)
          if (movedIds.contains(t.id)) t.id: (x: t.xMm, y: t.yMm),
      };
      if (old.isEmpty) return;
      ref
          .read(storageUndoProvider.notifier)
          .push(
            storage.id,
            "Di chuyển ${old.length} khay",
            () => repo.moveTrays(old),
          );
    }

    // Không bắt phím tắt khi đang gõ trong ô nhập
    bool typing() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
    void guarded(VoidCallback f) {
      if (!typing()) f();
    }

    void selectAll() => selected.value = trays.map((t) => t.id).toSet();
    void fitView() {
      zoom.value = 1.0;
      fitSignal.value++;
    }

    Future<void> undo() async {
      final label = await ref
          .read(storageUndoProvider.notifier)
          .pop(storage.id);
      if (label != null && context.mounted) {
        AppSnackBar.show(
          context,
          message: "Đã hoàn tác: $label",
          type: SnackBarType.success,
        );
      }
    }

    Future<void> showContextMenu(
      StorageTray? tray,
      int? compartment,
      Offset pos,
    ) async {
      if (tray != null && !selected.value.contains(tray.id)) {
        selected.value = {tray.id};
      }
      final sel = tray == null
          ? const <StorageTray>[]
          : trays
                .where((t) => selected.value.contains(t.id) || t.id == tray.id)
                .toList();
      final hasItems =
          tray != null &&
          compartment != null &&
          tray.variants.any((v) => v.compartmentIndex == compartment);
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final choice = await showMenu<String>(
        context: context,
        color: AppColors.background,
        position: RelativeRect.fromRect(
          pos & const Size(1, 1),
          Offset.zero & overlay.size,
        ),
        items: tray != null
            ? [
                PopupMenuItem(
                  value: "light",
                  enabled: sel.any((t) => t.hasLed),
                  child: const Text("Sáng thử"),
                ),
                if (sel.length == 1)
                  const PopupMenuItem(value: "rename", child: Text("Đổi tên…")),
                const PopupMenuItem(
                  value: "number",
                  child: Text("Đánh số LED cho vùng chọn…"),
                ),
                if (hasItems)
                  const PopupMenuItem(
                    value: "moveComp",
                    child: Text("Chuyển ngăn sang khay khác…"),
                  ),
                const PopupMenuItem(value: "dup", child: Text("Nhân bản")),
                const PopupMenuItem(value: "del", child: Text("Xoá")),
              ]
            : [
                const PopupMenuItem(value: "all", child: Text("Chọn tất cả")),
                const PopupMenuItem(value: "fit", child: Text("Vừa màn hình")),
                const PopupMenuItem(
                  value: "shift",
                  child: Text("Chèn / dời số LED…"),
                ),
                PopupMenuItem(
                  value: "wire",
                  child: Text(
                    showWire ? "Ẩn đường dây LED" : "Hiện đường dây LED",
                  ),
                ),
              ],
      );
      if (choice == null || !context.mounted) return;
      switch (choice) {
        case "light":
          await lightTrays(context, ref, storage, sel);
        case "rename":
          await StorageAction.renameTray(context, ref, sel.first);
        case "number":
          await showLedNumberDialog(context, ref, storage, sel, trays);
        case "moveComp":
          await StorageAction.pickAndMoveCompartment(
            context,
            ref,
            tray!,
            compartment!,
          );
        case "dup":
          final left = sel.map((t) => t.xMm).reduce((a, b) => a < b ? a : b);
          final right = sel
              .map((t) => t.xMm + t.frontWidthMm)
              .reduce((a, b) => a > b ? a : b);
          final created = await repo
              .duplicateTrays(sel.map((t) => t.id).toList(), dx: right - left)
              .withToast(context);
          if (created != null) selected.value = created.toSet();
        case "del":
          await StorageAction.deleteTrays(
            context,
            ref,
            sel.map((t) => t.id).toList(),
          );
        case "all":
          selectAll();
        case "fit":
          fitView();
        case "shift":
          await showLedShiftDialog(context, ref, storage);
        case "wire":
          wireOverride.value = !showWire;
      }
    }

    void nudge(double dx, double dy) {
      if (selected.value.isEmpty) return;
      final g = storage.gridMm;
      pushMoveUndo(selected.value);
      repo.moveTrays({
        for (final t in trays)
          if (selected.value.contains(t.id))
            t.id: (x: t.xMm + dx * g, y: t.yMm + dy * g),
      });
    }

    final editor = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.delete): () =>
            StorageAction.deleteTrays(context, ref, selected.value.toList()),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          selected.value = {};
          mode.value = CanvasMode.arrange;
        },
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
            guarded(selectAll),
        const SingleActivator(LogicalKeyboardKey.keyF): () => guarded(fitView),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
            guarded(undo),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => nudge(-1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => nudge(1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => nudge(0, -1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => nudge(0, 1),
      },
      child: Focus(
        focusNode: focus,
        autofocus: true,
        child: Listener(
          onPointerDown: (_) => focus.requestFocus(),
          child: StorageCanvas(
            storage: storage,
            trays: trays,
            selected: selected.value,
            mode: mode.value,
            zoom: zoom.value,
            onZoom: (z) => zoom.value = z,
            session: session,
            onSelect: (s) => selected.value = s,
            showWire: showWire,
            resetViewSignal: fitSignal.value,
            onContextMenu: showContextMenu,
            onTrayDoubleTap: (t) => StorageAction.renameTray(context, ref, t),
            onMoveCompartment: (from, fi, to, ti) =>
                StorageAction.moveCompartment(context, ref, from, fi, to, ti),
            onMove: (positions) {
              pushMoveUndo(positions.keys);
              repo.moveTrays({
                for (final e in positions.entries)
                  e.key: (x: e.value.dx, y: e.value.dy),
              });
            },
            onWireTap: (t) async {
              if (wireNext.value >= storage.ledCount) return;
              await repo.setLed(t.id, wireNext.value).withToast(context);
              wireNext.value++;
            },
            onDropType: (typeId, pos) {
              final type = trayTypes.where((t) => t.id == typeId).firstOrNull;
              if (type != null) addTray(type, pos);
            },
            onDropVariant: (v, t, c) =>
                repo.place(v.id, t.id, compartmentIndex: c).withToast(context),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          storage: storage,
          storages: storages,
          trays: trays,
          mode: mode.value,
          zoom: zoom.value,
          onStorageChanged: onStorageChanged,
          showWire: showWire,
          onToggleWire: () => wireOverride.value = !showWire,
          onMode: (m) {
            mode.value = m;
            wireOverride.value = null;
            if (m == CanvasMode.wire) {
              selected.value = {};
              final used = trays.where((t) => t.hasLed).map((t) => t.ledIndex);
              wireNext.value = used.isEmpty
                  ? 0
                  : (used.reduce((a, b) => a > b ? a : b) + 1).clamp(
                      0,
                      storage.ledCount,
                    );
            }
          },
          onZoom: (z) => zoom.value = z,
        ),
        if (mode.value == CanvasMode.wire)
          _WireBanner(
            next: wireNext.value,
            ledCount: storage.ledCount,
            onNext: (n) => wireNext.value = n,
            onDone: () => mode.value = CanvasMode.arrange,
          ),
        if (session != null) _SessionBanner(storage: storage, session: session),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 240,
                child: _LeftPanel(
                  trayTypes: trayTypes,
                  onAddTray: (t) => addTray(t),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: traysAsync.when(
                  data: (_) => editor,
                  loading: () => const AppLoadingView(),
                  error: (e, _) => AppErrorView(message: "Lỗi tải khay: $e"),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 310,
                child: TrayInspector(
                  storage: storage,
                  trays: trays,
                  trayTypes: trayTypes,
                  selected: selected.value,
                  onSelect: (s) => selected.value = s,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  final Storage storage;
  final List<Storage> storages;
  final List<StorageTray> trays;
  final CanvasMode mode;
  final double zoom;
  final bool showWire;
  final VoidCallback onToggleWire;
  final ValueChanged<int> onStorageChanged;
  final ValueChanged<CanvasMode> onMode;
  final ValueChanged<double> onZoom;

  const _Toolbar({
    required this.storage,
    required this.storages,
    required this.trays,
    required this.mode,
    required this.zoom,
    required this.showWire,
    required this.onToggleWire,
    required this.onStorageChanged,
    required this.onMode,
    required this.onZoom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(storageRepositoryProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int>(
            initialValue: storage.id,
            isDense: true,
            decoration: const InputDecoration(
              labelText: "Kho",
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final s in storages)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (id) {
              if (id != null) onStorageChanged(id);
            },
          ),
        ),
        IconButton(
          tooltip: "Cài đặt kho (kích thước, dải LED, nguồn)",
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => StorageAction.showStorage(context, ref, storage),
        ),
        IconButton(
          tooltip: "Thêm kho",
          icon: const Icon(Icons.add_box_outlined),
          onPressed: () async {
            final id = await StorageAction.showStorage(context, ref);
            if (id != null) onStorageChanged(id);
          },
        ),
        IconButton(
          tooltip: "Xoá kho",
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () => StorageAction.deleteStorage(context, ref, storage),
        ),
        const SizedBox(width: 8),
        SegmentedButton<CanvasMode>(
          segments: const [
            ButtonSegment(
              value: CanvasMode.arrange,
              label: Text("Sắp xếp"),
              icon: Icon(Icons.open_with_rounded),
            ),
            ButtonSegment(
              value: CanvasMode.wire,
              label: Text("Nối dây LED"),
              icon: Icon(Icons.cable_rounded),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (v) => onMode(v.first),
        ),
        IconButton(
          tooltip: showWire ? "Ẩn đường dây LED" : "Hiện đường dây LED",
          isSelected: showWire,
          icon: const Icon(Icons.timeline_rounded),
          selectedIcon: const Icon(
            Icons.timeline_rounded,
            color: AppColors.primary,
          ),
          onPressed: onToggleWire,
        ),
        PopupMenuButton<VoidCallback>(
          tooltip: "Đánh số LED",
          color: AppColors.background,
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            for (final order in LedOrder.values)
              PopupMenuItem(
                value: () async {
                  final n = await repo
                      .autoNumberLeds(storage.id, order)
                      .withToast(context);
                  if (n != null && context.mounted) {
                    AppSnackBar.show(
                      context,
                      message: "Đã đánh số $n LED",
                      type: SnackBarType.success,
                    );
                  }
                },
                child: Text("Đánh số tự động: ${order.label}"),
              ),
            PopupMenuItem(
              value: () => repo.clearLeds(storage.id),
              child: const Text("Bỏ LED của mọi khay"),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.format_list_numbered_rounded, size: 20),
                SizedBox(width: 4),
                Text("Đánh số LED"),
                Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        AppButton(
          label: "Sáng thử tất cả",
          icon: Icons.lightbulb_outline_rounded,
          variant: ButtonVariant.secondary,
          size: ButtonSize.small,
          isDisabled: !trays.any((t) => t.hasLed),
          onPressed: () => lightTrays(context, ref, storage, trays),
        ),
        SizedBox(
          width: 180,
          child: Row(
            children: [
              const Icon(Icons.zoom_in_rounded, size: 18),
              Expanded(
                // Thanh trượt theo thang log để dải zoom rộng vẫn dễ chỉnh
                child: Slider(
                  value: math.log(zoom),
                  min: math.log(StorageCanvas.minZoom),
                  max: math.log(StorageCanvas.maxZoom),
                  onChanged: (v) => onZoom(math.exp(v)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WireBanner extends StatelessWidget {
  final int next;
  final int ledCount;
  final ValueChanged<int> onNext;
  final VoidCallback onDone;

  const _WireBanner({
    required this.next,
    required this.ledCount,
    required this.onNext,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.cable_rounded, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              next >= ledCount
                  ? "Đã dùng hết $ledCount LED của kho."
                  : "Bấm lần lượt các khay theo đường đi thật của dải LED. "
                        "Khay bấm tiếp theo nhận LED số ${next + 1}.",
            ),
          ),
          IconButton(
            tooltip: "Lùi 1 LED",
            icon: const Icon(Icons.remove_rounded),
            onPressed: next > 0 ? () => onNext(next - 1) : null,
          ),
          Text(
            "LED ${next + 1}",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: "Bỏ qua 1 LED",
            icon: const Icon(Icons.add_rounded),
            onPressed: next < ledCount - 1 ? () => onNext(next + 1) : null,
          ),
          TextButton(onPressed: () => onNext(0), child: const Text("Từ đầu")),
          const SizedBox(width: 4),
          AppButton(label: "Xong", size: ButtonSize.small, onPressed: onDone),
        ],
      ),
    );
  }
}

class _SessionBanner extends HookConsumerWidget {
  final Storage storage;
  final LightSession session;

  const _SessionBanner({required this.storage, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useState(DateTime.now());
    useEffect(() {
      final t = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => now.value = DateTime.now(),
      );
      return t.cancel;
    }, const []);
    final left = session.endsAt.difference(now.value).inSeconds.clamp(0, 9999);
    final plan = session.plan;
    final peak = plan.peakMa(storage.mAPerChannel).round();
    final parts = [
      "Đang sáng ${plan.commands.length} LED${session.simulated ? " (giả lập)" : ""}",
      "còn ${left}s",
      "~$peak / ${plan.budgetMa.round()} mA",
      if (plan.groupCount > 1)
        "luân phiên ${plan.groupCount} lượt (lượt ${session.groupAt(now.value) + 1})",
      if (plan.groupCount == 1 && plan.scale < 1)
        "đã giảm sáng còn ${(plan.scale * 100).round()}% dòng",
    ];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(parts.join(" · "))),
          TextButton.icon(
            onPressed: () => ref
                .read(ledSessionsProvider.notifier)
                .off(storage)
                .withToast(context),
            icon: const Icon(Icons.power_settings_new_rounded),
            label: const Text("Tắt LED"),
          ),
        ],
      ),
    );
  }
}

class _LeftPanel extends HookConsumerWidget {
  final List<TrayType> trayTypes;
  final ValueChanged<TrayType> onAddTray;

  const _LeftPanel({required this.trayTypes, required this.onAddTray});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unplaced =
        ref.watch(watchUnplacedVariantsProvider).value ??
        const <ComponentVariant>[];
    final query = useState("");
    // Mặc định chỉ hiện biến thể còn hàng (đồ chưa mua thì chưa cần chỗ cất)
    final states = useState<Set<StockState>>({StockState.inStock});
    final searchOptions = ref.watch(searchOptionsProvider);
    final search = TextSearch(query.value, searchOptions);
    final counts = <StockState, int>{};
    for (final v in unplaced) {
      counts.update(StockState.of(v), (n) => n + 1, ifAbsent: () => 1);
    }
    final shown = unplaced
        .where((v) => states.value.contains(StockState.of(v)))
        .toList();
    final filtered = search.filter(shown, (v) => v.fullLabel);
    const title = TextStyle(fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Thêm khay", style: title),
        const Text(
          "Kéo vào sơ đồ, hoặc bấm để đặt vào chỗ trống",
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        for (final t in trayTypes)
          Draggable<int>(
            data: t.id,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(t.defaultColor).withValues(alpha: 0.3),
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t.name),
              ),
            ),
            child: Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                dense: true,
                mouseCursor: SystemMouseCursors.grab,
                leading: LedColorDot(color: t.defaultColor, size: 14),
                title: Text(t.name),
                subtitle: Text(
                  "${t.widthMm.round()}×${t.heightMm.round()} mm · "
                  "${t.compartmentCount} ngăn",
                ),
                trailing: const Icon(Icons.add_rounded, size: 18),
                onTap: () => onAddTray(t),
              ),
            ),
          ),
        const Divider(height: 24),
        Text("Chưa có chỗ (${shown.length})", style: title),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final st in StockState.values)
              FilterChip(
                label: Text("${st.label} (${counts[st] ?? 0})"),
                labelStyle: const TextStyle(fontSize: 11),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selected: states.value.contains(st),
                onSelected: (on) => states.value = on
                    ? {...states.value, st}
                    : ({...states.value}..remove(st)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          decoration: const InputDecoration(
            hintText: "Tìm linh kiện…",
            prefixIcon: Icon(Icons.search_rounded, size: 18),
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => query.value = v,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final v = filtered[i];
              final tile = ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                mouseCursor: SystemMouseCursors.grab,
                title: Text(
                  v.fullLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: v.stock == null ? null : Text("Còn ${v.stock}"),
                trailing: IconButton(
                  tooltip: "Gợi ý chỗ cất",
                  icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                  onPressed: () => PlacePickerDialog.show(context, v),
                ),
              );
              return Draggable<ComponentVariant>(
                data: v,
                feedback: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(v.fullLabel),
                  ),
                ),
                child: tile,
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// LOẠI KHAY
// =============================================================================

class _TrayTypesTab extends HookConsumerWidget {
  const _TrayTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final typesAsync = ref.watch(watchAllTrayTypesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton(
          label: "Thêm loại khay",
          icon: Icons.add_rounded,
          size: ButtonSize.small,
          onPressed: () => StorageAction.showTrayType(context, ref),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: typesAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, _) => AppErrorView(message: "$e"),
            data: (types) => ListView(
              children: [
                for (final t in types)
                  Card(
                    elevation: 0,
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      leading: LedColorDot(color: t.defaultColor),
                      title: Text(
                        t.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          "${t.widthMm.round()} × ${t.depthMm.round()} × "
                              "${t.heightMm.round()} mm",
                          if (t.stackGapMm > 0) "kê ${t.stackGapMm.round()} mm",
                          "${t.compartmentCount} ngăn"
                              "${t.removableDividers ? " (vách tháo được)" : ""}",
                          t.isColorFixed
                              ? "chỉ ${t.allowedColors.length} màu"
                              : "màu tự do",
                          "sáng ${t.minBrightness}–${t.maxBrightness}",
                          "${t.trays.length} khay đang dùng",
                          if (t.note.isNotEmpty) t.note,
                        ].join(" · "),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: "Sửa",
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                StorageAction.showTrayType(context, ref, t),
                          ),
                          IconButton(
                            tooltip: "Xoá",
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                StorageAction.deleteTrayType(context, ref, t),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// NGUỒN
// =============================================================================

class _SuppliesTab extends HookConsumerWidget {
  const _SuppliesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final suppliesAsync = ref.watch(watchAllPowerSuppliesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton(
          label: "Thêm nguồn",
          icon: Icons.add_rounded,
          size: ButtonSize.small,
          onPressed: () => StorageAction.showSupply(context, ref),
        ),
        const SizedBox(height: 8),
        const Text(
          "Độ sáng LED tự giảm theo dòng tối đa của nguồn đang chọn cho kho "
          "(chọn trong Cài đặt kho).",
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: suppliesAsync.when(
            loading: () => const AppLoadingView(),
            error: (e, _) => AppErrorView(message: "$e"),
            data: (supplies) => ListView(
              children: [
                for (final p in supplies)
                  Card(
                    elevation: 0,
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.power_rounded),
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          p.spec,
                          "dùng tối đa ${(p.derate * 100).round()}% = "
                              "${(p.currentA * p.derate * 1000).round()} mA",
                          if (p.note.isNotEmpty) p.note,
                        ].join(" · "),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: "Sửa",
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                StorageAction.showSupply(context, ref, p),
                          ),
                          IconButton(
                            tooltip: "Xoá",
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                StorageAction.deleteSupply(context, ref, p),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
