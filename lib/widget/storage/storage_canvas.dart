import 'dart:async';
import 'dart:math' as math;

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/notifier/led_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Chế độ thao tác trên sơ đồ kho.
enum CanvasMode {
  /// Kéo thả, chọn khay.
  arrange,

  /// Bấm lần lượt từng khay theo đường đi của dải LED để đánh số.
  wire,
}

/// Hình chữ nhật mặt trước của khay (mm).
Rect trayRect(StorageTray t) =>
    Rect.fromLTWH(t.xMm, t.yMm, t.frontWidthMm, t.frontHeightMm);

/// 2 khay chồng lên nhau (chạm cạnh không tính).
bool traysOverlap(Rect a, Rect b) =>
    a.left < b.right - 0.5 &&
    b.left < a.right - 0.5 &&
    a.top < b.bottom - 0.5 &&
    b.top < a.bottom - 0.5;

/// Chỗ trống đầu tiên (trên → dưới, trái → phải) đặt vừa khay [w] × [h].
Offset findFreeSpot(
  Storage storage,
  List<StorageTray> trays,
  double w,
  double h,
) {
  final rects = trays.map(trayRect).toList();
  final step = math.max(storage.gridMm, 5.0);
  for (var y = 0.0; y + h <= storage.heightMm; y += step) {
    for (var x = 0.0; x + w <= storage.widthMm; x += step) {
      final r = Rect.fromLTWH(x, y, w, h);
      if (!rects.any((o) => traysOverlap(r, o))) return Offset(x, y);
    }
  }
  return Offset.zero;
}

/// Bắt dính vị trí [r] (mm): vào cạnh khay khác nếu gần (≤ [magnet] mm), nếu
/// không thì vào lưới. Trả về độ dời cần cộng thêm.
Offset snapOffset(
  Rect r,
  List<Rect> others, {
  required double grid,
  double magnet = 8,
}) {
  double best(double value, List<double> candidates, double size) {
    double? pick;
    for (final c in candidates) {
      final d = (c - value).abs();
      if (d <= magnet && (pick == null || d < (pick - value).abs())) pick = c;
    }
    return pick ?? (value / grid).round() * grid;
  }

  final xs = <double>[
    for (final o in others) ...[
      o.left,
      o.right,
      o.left - r.width,
      o.right - r.width,
    ],
  ];
  final ys = <double>[
    for (final o in others) ...[
      o.top,
      o.bottom,
      o.top - r.height,
      o.bottom - r.height,
    ],
  ];
  final x = best(r.left, xs, r.width);
  final y = best(r.top, ys, r.height);
  return Offset(x - r.left, y - r.top);
}

/// Sơ đồ mặt trước của kho: khay kéo thả được, LED đang sáng nhấp nháy theo
/// đúng nhịp firmware (giả lập).
class StorageCanvas extends HookWidget {
  final Storage storage;
  final List<StorageTray> trays;
  final Set<int> selected;
  final CanvasMode mode;
  final double zoom;
  final LightSession? session;
  final ValueChanged<Set<int>> onSelect;
  final void Function(Map<int, Offset> positions) onMove;
  final ValueChanged<StorageTray> onWireTap;
  final void Function(int trayTypeId, Offset positionMm) onDropType;
  final void Function(
    ComponentVariant variant,
    StorageTray tray,
    int compartment,
  )
  onDropVariant;

  const StorageCanvas({
    super.key,
    required this.storage,
    required this.trays,
    required this.selected,
    required this.mode,
    required this.zoom,
    required this.session,
    required this.onSelect,
    required this.onMove,
    required this.onWireTap,
    required this.onDropType,
    required this.onDropVariant,
  });

  @override
  Widget build(BuildContext context) {
    final stackKey = useMemoized(GlobalKey.new);
    // Độ dời đang kéo (mm) của các khay được chọn
    final drag = useState<Offset?>(null);
    final dragIds = useRef<Set<int>>({});

    // Nhịp nhấp nháy khi đang sáng
    final tick = useState(0);
    useEffect(() {
      if (session == null) return null;
      final timer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => tick.value++,
      );
      return timer.cancel;
    }, [session]);

    final rects = {for (final t in trays) t.id: trayRect(t)};
    final overlapping = <int>{
      for (final a in trays)
        for (final b in trays)
          if (a.id != b.id && traysOverlap(rects[a.id]!, rects[b.id]!)) a.id,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = math.min(
          (constraints.maxWidth - 2) / storage.widthMm,
          (constraints.maxHeight - 2) / storage.heightMm,
        );
        final scale = math.max(fit, 0.05) * zoom;
        final width = storage.widthMm * scale;
        final height = storage.heightMm * scale;

        Offset toMm(Offset global) {
          final box = stackKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return Offset.zero;
          final local = box.globalToLocal(global);
          return Offset(local.dx / scale, local.dy / scale);
        }

        void endDrag() {
          final delta = drag.value;
          drag.value = null;
          if (delta == null || dragIds.value.isEmpty) return;
          final moving = dragIds.value;
          final union = moving
              .map((id) => rects[id]!.shift(delta))
              .reduce((a, b) => a.expandToInclude(b));
          final others = [
            for (final t in trays)
              if (!moving.contains(t.id)) rects[t.id]!,
          ];
          final snap = snapOffset(union, others, grid: storage.gridMm);
          final total = delta + snap;
          onMove({
            for (final id in moving)
              id: Offset(
                (rects[id]!.left + total.dx).clamp(
                  0,
                  math.max(0, storage.widthMm - rects[id]!.width),
                ),
                (rects[id]!.top + total.dy).clamp(
                  0,
                  math.max(0, storage.heightMm - rects[id]!.height),
                ),
              ),
          });
        }

        final now = DateTime.now();
        final group = session?.groupAt(now) ?? 0;
        final elapsed = session == null
            ? 0
            : now.difference(session!.startedAt).inMilliseconds;

        Widget trayWidget(StorageTray t) {
          final isDragging = drag.value != null && dragIds.value.contains(t.id);
          final r = isDragging ? rects[t.id]!.shift(drag.value!) : rects[t.id]!;
          final cmd = t.hasLed ? session?.commandOf(t.ledIndex) : null;
          final lit =
              cmd != null && cmd.group == group && cmd.effect.isOnAt(elapsed);
          return Positioned(
            left: r.left * scale,
            top: r.top * scale,
            width: r.width * scale,
            height: r.height * scale,
            child: GestureDetector(
              onTap: () {
                if (mode == CanvasMode.wire) {
                  onWireTap(t);
                  return;
                }
                final keys = HardwareKeyboard.instance;
                if (keys.isShiftPressed || keys.isControlPressed) {
                  onSelect(
                    selected.contains(t.id)
                        ? ({...selected}..remove(t.id))
                        : {...selected, t.id},
                  );
                } else {
                  onSelect({t.id});
                }
              },
              onPanStart: mode == CanvasMode.arrange
                  ? (_) {
                      if (!selected.contains(t.id)) {
                        onSelect({t.id});
                        dragIds.value = {t.id};
                      } else {
                        dragIds.value = {...selected};
                      }
                      drag.value = Offset.zero;
                    }
                  : null,
              onPanUpdate: mode == CanvasMode.arrange
                  ? (d) => drag.value =
                        (drag.value ?? Offset.zero) + d.delta / scale
                  : null,
              onPanEnd: mode == CanvasMode.arrange ? (_) => endDrag() : null,
              onPanCancel: () => drag.value = null,
              child: MouseRegion(
                cursor: mode == CanvasMode.arrange
                    ? SystemMouseCursors.move
                    : SystemMouseCursors.click,
                child: _TrayBox(
                  tray: t,
                  scale: scale,
                  selected: selected.contains(t.id),
                  overlapping: overlapping.contains(t.id),
                  wireMode: mode == CanvasMode.wire,
                  glowColor: lit
                      ? Color(session!.trayColors[t.id] ?? cmd.argb)
                      : null,
                  onDropVariant: (v, c) => onDropVariant(v, t, c),
                ),
              ),
            ),
          );
        }

        final canvas = DragTarget<int>(
          onAcceptWithDetails: (details) =>
              onDropType(details.data, toMm(details.offset)),
          builder: (context, candidates, _) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect({}),
            child: Container(
              key: stackKey,
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: candidates.isNotEmpty
                    ? AppColors.primaryLight
                    : AppColors.surface,
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: CustomPaint(
                painter: _GridPainter(
                  scale: scale,
                  stepMm: _gridStep(storage.gridMm, scale),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [for (final t in trays) trayWidget(t)],
                ),
              ),
            ),
          ),
        );

        return Scrollbar(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(padding: const EdgeInsets.all(1), child: canvas),
            ),
          ),
        );
      },
    );
  }

  /// Bước vẽ lưới: bội số của bước bắt dính, các đường cách nhau ≥ 12px.
  static double _gridStep(double gridMm, double scale) {
    var step = gridMm;
    while (step * scale < 12) {
      step *= 2;
    }
    return step;
  }
}

class _GridPainter extends CustomPainter {
  final double scale;
  final double stepMm;

  _GridPainter({required this.scale, required this.stepMm});

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    final major = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    var i = 0;
    for (var x = 0.0; x <= size.width; x += stepMm * scale, i++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % 5 == 0 ? major : minor,
      );
    }
    i = 0;
    for (var y = 0.0; y <= size.height; y += stepMm * scale, i++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i % 5 == 0 ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.scale != scale || old.stepMm != stepMm;
}

class _TrayBox extends StatelessWidget {
  final StorageTray tray;
  final double scale;
  final bool selected;
  final bool overlapping;
  final bool wireMode;
  final Color? glowColor;
  final void Function(ComponentVariant variant, int compartment) onDropVariant;

  const _TrayBox({
    required this.tray,
    required this.scale,
    required this.selected,
    required this.overlapping,
    required this.wireMode,
    required this.glowColor,
    required this.onDropVariant,
  });

  @override
  Widget build(BuildContext context) {
    final type = tray.trayType.target;
    final tint = Color(type?.defaultColor ?? 0xFF888888);
    final gapPx = (type?.stackGapMm ?? 0) * scale;
    final sizes = tray.compartmentSizes();
    final count = sizes.length;
    final vertical = type?.compartmentVertical ?? false;
    final contents = <int, List<ComponentVariant>>{};
    for (final v in tray.variants) {
      contents.putIfAbsent(v.compartmentIndex, () => []).add(v);
    }
    final small = tray.frontHeightMm * scale < 34;

    final borderColor = overlapping
        ? AppColors.error
        : selected
        ? AppColors.primary
        : AppColors.textMuted;

    final compartments = Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            flex: sizes[i],
            child: DragTarget<ComponentVariant>(
              onAcceptWithDetails: (d) => onDropVariant(d.data, i),
              builder: (context, candidates, _) {
                final items = contents[i] ?? const [];
                return Container(
                  decoration: BoxDecoration(
                    color: candidates.isNotEmpty
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : null,
                    border: i == 0
                        ? null
                        : Border(
                            left: vertical
                                ? BorderSide.none
                                : const BorderSide(
                                    color: AppColors.borderStrong,
                                  ),
                            top: vertical
                                ? const BorderSide(
                                    color: AppColors.borderStrong,
                                  )
                                : BorderSide.none,
                          ),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(2),
                  child: items.isEmpty || small
                      ? null
                      : Tooltip(
                          message: items.map((v) => v.fullLabel).join("\n"),
                          child: Text(
                            items.length == 1
                                ? items.first.fullLabel
                                : "${items.length} linh kiện",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thanh kê phía trên khay
        if (gapPx >= 1)
          Container(
            height: gapPx,
            margin: EdgeInsets.symmetric(horizontal: gapPx > 6 ? 6 : 0),
            color: AppColors.surfaceVariant,
          ),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            decoration: BoxDecoration(
              // Nền đặc để lưới không xuyên qua khay
              color: Color.alphaBlend(
                glowColor?.withValues(alpha: 0.55) ??
                    tint.withValues(alpha: 0.12),
                AppColors.surface,
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: borderColor,
                width: selected || overlapping ? 2.5 : 1,
              ),
              boxShadow: glowColor == null
                  ? null
                  : [
                      BoxShadow(
                        color: glowColor!.withValues(alpha: 0.9),
                        blurRadius: 18,
                        spreadRadius: 3,
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Positioned.fill(child: compartments),
                Positioned(
                  left: 3,
                  top: 1,
                  child: IgnorePointer(
                    child: Text(
                      tray.label,
                      style: TextStyle(
                        fontSize: small ? 9 : 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: IgnorePointer(
                    child: _LedBadge(index: tray.ledIndex, big: wireMode),
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

/// Số thứ tự LED (hiển thị từ 1) của khay.
class _LedBadge extends StatelessWidget {
  final int index;
  final bool big;

  const _LedBadge({required this.index, required this.big});

  @override
  Widget build(BuildContext context) {
    final has = index >= 0;
    final size = big ? 24.0 : 16.0;
    return Container(
      constraints: BoxConstraints(minWidth: size),
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: has ? AppColors.textMain : AppColors.surface,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: has ? AppColors.textMain : AppColors.borderStrong,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        has ? "${index + 1}" : "–",
        style: TextStyle(
          fontSize: big ? 12 : 9,
          fontWeight: FontWeight.w700,
          color: has ? Colors.white : AppColors.textDisabled,
        ),
      ),
    );
  }
}
