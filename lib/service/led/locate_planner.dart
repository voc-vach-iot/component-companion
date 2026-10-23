import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/util/led_plan.dart';

/// 1 biến thể cần tìm trong kho. [color] = màu muốn dùng (null = tự chọn).
class LocateTarget {
  final ComponentVariant variant;
  final int? color;

  const LocateTarget(this.variant, {this.color});
}

/// Kết quả chuẩn bị sáng cho 1 kho.
class LocateRequest {
  final Storage storage;
  final List<LedRequest> requests;

  /// LED -> các nhãn (VD "Tụ 100nF · F0-03 / ngăn 2") để hiển thị.
  final Map<int, List<String>> labels;

  /// Khay đang sáng -> màu hiển thị (ARGB) trên sơ đồ.
  final Map<int, int> trayColors;

  const LocateRequest({
    required this.storage,
    required this.requests,
    required this.labels,
    required this.trayColors,
  });
}

/// Không sáng được: chưa có chỗ / khay chưa gắn LED.
class LocateMiss {
  final ComponentVariant variant;
  final String reason;

  const LocateMiss(this.variant, this.reason);
}

/// Chuyển danh sách linh kiện cần tìm thành yêu cầu sáng LED theo từng kho.
///
/// - Màu báo ngăn ([TrayType.colorForCompartment], mặc định đỏ / xanh lá / xanh
///   dương thuần — 1 kênh LED nên ít tốn điện nhất), LED sáng liên tục.
/// - Khay màu cố định (VD A6 chỉ xanh dương) nhiều ngăn: nháy N lần theo số ngăn.
/// - Tìm nhiều linh kiện: phân biệt linh kiện bằng kiểu nháy (sáng / nháy chậm /
///   nháy nhanh) theo thứ tự, màu vẫn báo ngăn.
/// - 2 linh kiện cùng 1 khay: giữ linh kiện đầu, nhãn ghi cả hai.
class LocatePlanner {
  static const _distinctEffects = [
    LedEffect.solid,
    LedEffect.blinkSlow,
    LedEffect.blinkFast,
  ];

  static ({List<LocateRequest> requests, List<LocateMiss> misses}) plan(
    List<LocateTarget> targets, {
    double brightness = 1,
  }) {
    final misses = <LocateMiss>[];
    final byStorage = <int, _StorageBuild>{};
    final multi = targets.length > 1;

    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final variant = target.variant;
      final StorageTray? tray = variant.tray.target;
      final storage = tray?.storage.target;
      final type = tray?.trayType.target;
      if (tray == null || storage == null || type == null) {
        misses.add(LocateMiss(variant, "Chưa có chỗ cất"));
        continue;
      }
      if (!tray.hasLed || tray.ledIndex >= storage.ledCount) {
        misses.add(LocateMiss(variant, "Khay ${tray.label} chưa gắn LED"));
        continue;
      }
      final build = byStorage.putIfAbsent(
        storage.id,
        () => _StorageBuild(storage),
      );
      final label =
          "${variant.fullLabel} · ${tray.compartmentLabel(variant.compartmentIndex)}";
      final existing = build.requests[tray.ledIndex];
      build.labels.putIfAbsent(tray.ledIndex, () => []).add(label);
      if (existing != null) continue;

      final order = build.requests.length;
      final compartments = tray.compartmentCount;
      final color = type.resolveColor(
        target.color ??
            type.colorForCompartment(variant.compartmentIndex, compartments),
      );
      var effect = multi
          ? _distinctEffects[order % _distinctEffects.length]
          : LedEffect.solid;
      if (type.isColorFixed && compartments > 1) {
        effect = LedEffect.forCompartment(variant.compartmentIndex);
      }
      build.requests[tray.ledIndex] = LedRequest(
        ledIndex: tray.ledIndex,
        color: color,
        brightness: (type.maxBrightness * brightness).round().clamp(
          type.minBrightness,
          255,
        ),
        minBrightness: type.minBrightness,
        effect: effect,
      );
      build.trayColors[tray.id] = color;
    }

    return (
      requests: [
        for (final b in byStorage.values)
          LocateRequest(
            storage: b.storage,
            requests: b.requests.values.toList(),
            labels: b.labels,
            trayColors: b.trayColors,
          ),
      ],
      misses: misses,
    );
  }
}

class _StorageBuild {
  final Storage storage;
  final requests = <int, LedRequest>{};
  final labels = <int, List<String>>{};
  final trayColors = <int, int>{};

  _StorageBuild(this.storage);
}
