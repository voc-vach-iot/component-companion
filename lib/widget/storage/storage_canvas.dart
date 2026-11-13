import 'dart:async';
import 'dart:math' as math;

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/notifier/led_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
  final ValueChanged<double> onZoom;
  final void Function(Map<int, Offset> positions) onMove;
  final ValueChanged<StorageTray> onWireTap;
  final void Function(int trayTypeId, Offset positionMm) onDropType;
  final void Function(
    ComponentVariant variant,
    StorageTray tray,
    int compartment,
  )
  onDropVariant;

  /// Hiện đường dây LED (nối các khay theo thứ tự ledIndex).
  final bool showWire;

  /// Tăng giá trị này để đưa khung nhìn về góc trên trái (phím F).
  final int resetViewSignal;

  /// Chuột phải bấm (không kéo): [tray] / [compartment] null nếu bấm vào nền.
  final void Function(
    StorageTray? tray,
    int? compartment,
    Offset globalPosition,
  )?
  onContextMenu;

  /// Bấm đúp vào khay (chế độ sắp xếp).
  final ValueChanged<StorageTray>? onTrayDoubleTap;

  /// Alt + kéo ngăn thả sang ngăn khác.
  final void Function(
    StorageTray from,
    int fromIndex,
    StorageTray to,
    int toIndex,
  )?
  onMoveCompartment;

  const StorageCanvas({
    super.key,
    required this.storage,
    required this.trays,
    required this.selected,
    required this.mode,
    required this.zoom,
    required this.session,
    required this.onSelect,
    required this.onZoom,
    required this.onMove,
    required this.onWireTap,
    required this.onDropType,
    required this.onDropVariant,
    this.showWire = false,
    this.resetViewSignal = 0,
    this.onContextMenu,
    this.onTrayDoubleTap,
    this.onMoveCompartment,
  });

  static const minZoom = 0.2;
  static const maxZoom = 12.0;

  @override
  Widget build(BuildContext context) {
    final stackKey = useMemoized(GlobalKey.new);
    final vScroll = useScrollController();
    final hScroll = useScrollController();
    // Giữ Space để kéo nền (cuộn sơ đồ) thay vì kéo khay; chuột giữa cũng kéo nền
    final spaceHeld = useState(false);
    // Giữ Alt để kéo ngăn sang ngăn khác (tắt kéo khay)
    final altHeld = useState(false);
    final panning = useRef(false);
    // Chuột phải: kéo = cuộn, nhả với dịch chuyển < 4px = bấm phải (menu)
    final rightDown = useRef<Offset?>(null);
    final rightTravel = useRef(0.0);
    // Khung chọn vùng (mm) và vùng chọn có sẵn khi bắt đầu kéo
    final marquee = useState<Rect?>(null);
    final marqueeStart = useRef(Offset.zero);
    final marqueeBase = useRef<Set<int>>({});
    useEffect(() {
      bool onKey(KeyEvent e) {
        if (e.logicalKey == LogicalKeyboardKey.space) {
          if (e is KeyDownEvent) spaceHeld.value = true;
          if (e is KeyUpEvent) spaceHeld.value = false;
        }
        altHeld.value = HardwareKeyboard.instance.isAltPressed;
        return false;
      }

      HardwareKeyboard.instance.addHandler(onKey);
      return () => HardwareKeyboard.instance.removeHandler(onKey);
    }, const []);
    useEffect(() {
      if (resetViewSignal == 0) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in [hScroll, vScroll]) {
          if (c.hasClients) c.jumpTo(0);
        }
      });
      return null;
    }, [resetViewSignal]);
    // Độ dời đang kéo (mm) của các khay được chọn
    final drag = useState<Offset?>(null);
    // Lần bấm khay gần nhất (tự nhận nháy đúp để bấm 1 lần chọn ngay, không chờ)
    final lastTap = useRef<(int, DateTime)?>(null);
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
          final canDragTray =
              mode == CanvasMode.arrange && !spaceHeld.value && !altHeld.value;
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
                final prev = lastTap.value;
                final now = DateTime.now();
                if (prev != null &&
                    prev.$1 == t.id &&
                    now.difference(prev.$2) < kDoubleTapTimeout) {
                  lastTap.value = null;
                  onTrayDoubleTap?.call(t);
                  return;
                }
                lastTap.value = (t.id, now);
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
              onPanStart: canDragTray
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
              onPanUpdate: canDragTray
                  ? (d) => drag.value =
                        (drag.value ?? Offset.zero) + d.delta / scale
                  : null,
              onPanEnd: canDragTray ? (_) => endDrag() : null,
              onPanCancel: () => drag.value = null,
              child: MouseRegion(
                cursor: spaceHeld.value
                    ? SystemMouseCursors.grab
                    : mode == CanvasMode.arrange
                    ? SystemMouseCursors.move
                    : SystemMouseCursors.click,
                child: _TrayBox(
                  tray: t,
                  scale: scale,
                  selected: selected.contains(t.id),
                  overlapping: overlapping.contains(t.id),
                  wireMode: mode == CanvasMode.wire,
                  altHeld: altHeld.value,
                  onMoveCompartment: (from, fi, ti) =>
                      onMoveCompartment?.call(from, fi, t, ti),
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
            onPanStart: mode == CanvasMode.arrange && !spaceHeld.value
                ? (d) {
                    final keys = HardwareKeyboard.instance;
                    marqueeBase.value =
                        keys.isShiftPressed || keys.isControlPressed
                        ? {...selected}
                        : <int>{};
                    marqueeStart.value = d.localPosition / scale;
                    marquee.value = Rect.fromPoints(
                      marqueeStart.value,
                      marqueeStart.value,
                    );
                  }
                : null,
            onPanUpdate: mode == CanvasMode.arrange && !spaceHeld.value
                ? (d) {
                    final box = Rect.fromPoints(
                      marqueeStart.value,
                      d.localPosition / scale,
                    );
                    marquee.value = box;
                    onSelect({
                      ...marqueeBase.value,
                      for (final t in trays)
                        if (rects[t.id]!.overlaps(box)) t.id,
                    });
                  }
                : null,
            onPanEnd: (_) => marquee.value = null,
            onPanCancel: () => marquee.value = null,
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
                  children: [
                    for (final t in trays) trayWidget(t),
                    if (showWire)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _WirePainter(
                              scale: scale,
                              points: [
                                for (final t in trays)
                                  if (t.hasLed)
                                    (
                                      led: t.ledIndex,
                                      center:
                                          (drag.value != null &&
                                                      dragIds.value.contains(
                                                        t.id,
                                                      )
                                                  ? rects[t.id]!.shift(
                                                      drag.value!,
                                                    )
                                                  : rects[t.id]!)
                                              .center,
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (marquee.value != null)
                      Positioned.fromRect(
                        rect: Rect.fromLTRB(
                          marquee.value!.left * scale,
                          marquee.value!.top * scale,
                          marquee.value!.right * scale,
                          marquee.value!.bottom * scale,
                        ),
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              border: Border.all(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        void scrollBy(Offset delta) {
          for (final (c, d) in [(hScroll, delta.dx), (vScroll, delta.dy)]) {
            if (!c.hasClients) continue;
            c.jumpTo((c.offset + d).clamp(0.0, c.position.maxScrollExtent));
          }
        }

        // Lăn (hoặc Ctrl + lăn): phóng to / thu nhỏ quanh con trỏ;
        // Shift + lăn: cuộn ngang. Kéo sơ đồ bằng chuột phải / giữa.
        void onSignal(PointerSignalEvent e) {
          if (e is! PointerScrollEvent) return;
          final keys = HardwareKeyboard.instance;
          if (!keys.isShiftPressed) {
            GestureBinding.instance.pointerSignalResolver.register(e, (_) {
              final next = (zoom * math.exp(-e.scrollDelta.dy / 400)).clamp(
                minZoom,
                maxZoom,
              );
              if (next == zoom) return;
              // Điểm (mm) dưới con trỏ phải đứng yên sau khi đổi zoom
              final mm = toMm(e.position);
              final box = stackKey.currentContext?.findRenderObject();
              final viewPoint = box is RenderBox
                  ? box.localToGlobal(Offset.zero)
                  : Offset.zero;
              final ratio = next / zoom;
              onZoom(next.toDouble());
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final shift = Offset(
                  mm.dx * scale * ratio - (e.position.dx - viewPoint.dx),
                  mm.dy * scale * ratio - (e.position.dy - viewPoint.dy),
                );
                scrollBy(shift);
              });
            });
          } else if (keys.isShiftPressed) {
            GestureBinding.instance.pointerSignalResolver.register(e, (_) {
              scrollBy(Offset(e.scrollDelta.dy, 0));
            });
          }
        }

        return Listener(
          onPointerSignal: onSignal,
          onPointerDown: (e) {
            panning.value =
                e.buttons == kMiddleMouseButton ||
                (spaceHeld.value && e.buttons == kPrimaryMouseButton);
            if (e.buttons == kSecondaryMouseButton) {
              rightDown.value = e.position;
              rightTravel.value = 0;
            }
          },
          onPointerMove: (e) {
            if (panning.value) scrollBy(-e.delta);
            if (rightDown.value != null) {
              rightTravel.value += e.delta.distance;
              if (rightTravel.value >= 4) scrollBy(-e.delta);
            }
          },
          onPointerUp: (e) {
            panning.value = false;
            final down = rightDown.value;
            rightDown.value = null;
            if (down != null && rightTravel.value < 4) {
              final mm = toMm(down);
              StorageTray? hitTray;
              int? comp;
              for (final t in trays.reversed) {
                if (rects[t.id]!.contains(mm)) {
                  hitTray = t;
                  comp = _compartmentAt(t, mm);
                  break;
                }
              }
              onContextMenu?.call(hitTray, comp, down);
            }
          },
          onPointerCancel: (_) {
            panning.value = false;
            rightDown.value = null;
          },
          child: Scrollbar(
            controller: vScroll,
            // Tự xử lý con lăn (zoom) nên tắt cuộn mặc định của con lăn
            child: SingleChildScrollView(
              controller: vScroll,
              physics: const NeverScrollableScrollPhysics(),
              child: SingleChildScrollView(
                controller: hScroll,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(padding: const EdgeInsets.all(1), child: canvas),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Chỉ số ngăn của khay [t] tại điểm [mm] (đã nằm trong khay).
  static int _compartmentAt(StorageTray t, Offset mm) {
    final r = trayRect(t);
    final type = t.trayType.target;
    final vertical = type?.compartmentVertical ?? false;
    final gap = type?.stackGapMm ?? 0;
    final sizes = t.compartmentSizes();
    if (sizes.isEmpty) return 0;
    final total = sizes.fold<int>(0, (a, b) => a + b);
    final length = vertical ? r.height - gap : r.width;
    final local = vertical ? mm.dy - r.top - gap : mm.dx - r.left;
    final pos = (local / math.max(length, 0.001)) * total;
    var acc = 0;
    for (var i = 0; i < sizes.length; i++) {
      acc += sizes[i];
      if (pos < acc) return i;
    }
    return sizes.length - 1;
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

/// Đường dây LED: nối tâm các khay theo ledIndex tăng dần, mũi tên chỉ chiều,
/// đoạn nhảy cách vẽ nét đứt.
class _WirePainter extends CustomPainter {
  final double scale;
  final List<({int led, Offset center})> points;

  _WirePainter({required this.scale, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final sorted = [...points]..sort((a, b) => a.led.compareTo(b.led));
    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = AppColors.primary;
    for (var i = 0; i + 1 < sorted.length; i++) {
      final a = sorted[i].center * scale;
      final b = sorted[i + 1].center * scale;
      final contiguous = sorted[i + 1].led == sorted[i].led + 1;
      if (contiguous) {
        canvas.drawLine(a, b, line);
      } else {
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 12) {
            canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), line);
          }
        }
      }
      final dir = b - a;
      if (dir.distance < 1) continue;
      final u = dir / dir.distance;
      final n = Offset(-u.dy, u.dx);
      final tip = (a + b) / 2 + u * 6;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - u.dx * 12 + n.dx * 6, tip.dy - u.dy * 12 + n.dy * 6)
          ..lineTo(tip.dx - u.dx * 12 - n.dx * 6, tip.dy - u.dy * 12 - n.dy * 6)
          ..close(),
        fill,
      );
    }
    // Điểm đầu (LED đầu tiên)
    final start = sorted.first.center * scale;
    canvas.drawCircle(start, 8, fill);
    canvas.drawCircle(
      start,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_WirePainter old) =>
      old.scale != scale || !listEquals(old.points, points);
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

/// Dữ liệu kéo của một ngăn (Alt + kéo).
class _CompartmentRef {
  final StorageTray tray;
  final int index;

  const _CompartmentRef(this.tray, this.index);
}

class _TrayBox extends StatelessWidget {
  final StorageTray tray;
  final double scale;
  final bool selected;
  final bool overlapping;
  final bool wireMode;
  final Color? glowColor;
  final bool altHeld;
  final void Function(ComponentVariant variant, int compartment) onDropVariant;
  final void Function(StorageTray from, int fromIndex, int toIndex)
  onMoveCompartment;

  const _TrayBox({
    required this.tray,
    required this.scale,
    required this.selected,
    required this.overlapping,
    required this.wireMode,
    required this.glowColor,
    required this.altHeld,
    required this.onDropVariant,
    required this.onMoveCompartment,
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
            child: DragTarget<_CompartmentRef>(
              onWillAcceptWithDetails: (d) =>
                  !(d.data.tray.id == tray.id && d.data.index == i),
              onAcceptWithDetails: (d) =>
                  onMoveCompartment(d.data.tray, d.data.index, i),
              builder: (context, moveCandidates, _) => DragTarget<ComponentVariant>(
                onAcceptWithDetails: (d) => onDropVariant(d.data, i),
                builder: (context, candidates, _) {
                  final items = contents[i] ?? const [];
                  final cell = Container(
                    decoration: BoxDecoration(
                      color: candidates.isNotEmpty || moveCandidates.isNotEmpty
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
                  if (!altHeld || items.isEmpty) return cell;
                  return Draggable<_CompartmentRef>(
                    data: _CompartmentRef(tray, i),
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Ngăn ${i + 1} – khay ${tray.label}, ${items.length} linh kiện",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    child: cell,
                  );
                },
              ),
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
