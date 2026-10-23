import 'dart:async';

import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/service/led/ble_led_controller.dart';
import 'package:component_companion/service/led/led_controller.dart';
import 'package:component_companion/service/led/locate_planner.dart';
import 'package:component_companion/util/led_plan.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'led_notifier.g.dart';

/// Lần sáng đang diễn ra trên 1 kho.
class LightSession {
  final int storageId;
  final LedPlan plan;
  final Map<int, List<String>> labels;
  final Map<int, int> trayColors;
  final DateTime startedAt;
  final int timeoutS;
  final int rotateMs;
  final bool simulated;

  const LightSession({
    required this.storageId,
    required this.plan,
    required this.labels,
    required this.trayColors,
    required this.startedAt,
    required this.timeoutS,
    required this.rotateMs,
    required this.simulated,
  });

  DateTime get endsAt => startedAt.add(Duration(seconds: timeoutS));

  /// Lệnh của LED [ledIndex] (null = LED tắt).
  LedCommand? commandOf(int ledIndex) =>
      plan.commands.where((c) => c.ledIndex == ledIndex).firstOrNull;

  /// Lượt đang sáng tại thời điểm [now].
  int groupAt(DateTime now) {
    if (plan.groupCount <= 1 || rotateMs <= 0) return 0;
    final elapsed = now.difference(startedAt).inMilliseconds;
    return (elapsed ~/ rotateMs) % plan.groupCount;
  }
}

/// Kết quả 1 lần tìm.
class LocateResult {
  final List<LightSession> sessions;
  final List<LocateMiss> misses;

  const LocateResult(this.sessions, this.misses);

  int get litCount =>
      sessions.fold(0, (sum, s) => sum + s.plan.commands.length);
}

/// Yêu cầu trang Kho mở tab sơ đồ của 1 kho (VD bấm "Xem kho" sau khi tìm).
/// [token] tăng mỗi lần yêu cầu để bấm lại cùng kho vẫn có tác dụng.
@Riverpod(keepAlive: true)
class StorageFocus extends _$StorageFocus {
  @override
  ({int storageId, int token})? build() => null;

  void show(int storageId) =>
      state = (storageId: storageId, token: (state?.token ?? 0) + 1);
}

/// Bộ điều khiển LED theo thiết bị BLE đã ghép ([deviceId] rỗng = giả lập).
@Riverpod(keepAlive: true)
LedController ledController(Ref ref, String deviceId) =>
    deviceId.isEmpty ? SimulatedLedController() : BleLedController(deviceId);

/// Các kho đang sáng LED: storageId -> phiên sáng. Tự xoá khi hết giờ.
@Riverpod(keepAlive: true)
class LedSessions extends _$LedSessions {
  final _timers = <int, Timer>{};

  @override
  Map<int, LightSession> build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
    });
    return const {};
  }

  /// Sáng các linh kiện [targets] (gom theo kho, giới hạn dòng theo nguồn).
  Future<LocateResult> locate(
    List<LocateTarget> targets, {
    double brightness = 1,
  }) async {
    final planned = LocatePlanner.plan(targets, brightness: brightness);
    final sessions = <LightSession>[];
    for (final r in planned.requests) {
      sessions.add(
        await _send(
          r.storage,
          r.requests,
          labels: r.labels,
          trayColors: r.trayColors,
        ),
      );
    }
    return LocateResult(sessions, planned.misses);
  }

  /// Sáng thẳng các LED (VD "Thử LED", nối dây).
  Future<LightSession> lightRaw(
    Storage storage,
    List<LedRequest> requests, {
    Map<int, List<String>> labels = const {},
    Map<int, int> trayColors = const {},
  }) => _send(storage, requests, labels: labels, trayColors: trayColors);

  Future<LightSession> _send(
    Storage storage,
    List<LedRequest> requests, {
    required Map<int, List<String>> labels,
    required Map<int, int> trayColors,
  }) async {
    final supply = storage.powerSupply.target;
    final plan = LedPlanner.plan(
      requests,
      LedPowerSpec(
        // Chưa chọn nguồn => giả định 5V 1A cho an toàn
        supplyCurrentA: supply?.currentA ?? 1,
        derate: supply?.derate ?? 0.8,
        ledCount: storage.ledCount,
        mAPerChannel: storage.mAPerChannel,
        idleMaPerLed: storage.idleMaPerLed,
        mcuMa: storage.mcuMa,
      ),
    );
    const rotateMs = 3000;
    final controller = ref.read(ledControllerProvider(storage.bleDeviceId));
    await controller.show(storage, plan, rotateMs: rotateMs);
    final session = LightSession(
      storageId: storage.id,
      plan: plan,
      labels: labels,
      trayColors: trayColors,
      startedAt: DateTime.now(),
      timeoutS: storage.lightTimeoutS,
      rotateMs: rotateMs,
      simulated: controller.simulated,
    );
    _timers[storage.id]?.cancel();
    _timers[storage.id] = Timer(
      Duration(seconds: storage.lightTimeoutS),
      () => _remove(storage.id),
    );
    state = {...state, storage.id: session};
    return session;
  }

  void _remove(int storageId) {
    _timers.remove(storageId)?.cancel();
    if (!state.containsKey(storageId)) return;
    state = {...state}..remove(storageId);
  }

  Future<void> off(Storage storage) async {
    await ref.read(ledControllerProvider(storage.bleDeviceId)).off(storage);
    _remove(storage.id);
  }
}
