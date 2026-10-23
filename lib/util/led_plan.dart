import 'dart:math' as math;

/// Hiệu ứng của 1 LED. Mã [code] gửi xuống firmware (khớp `docs/kho-thong-minh.md`).
enum LedEffect {
  solid(0, "Sáng liên tục"),
  blinkSlow(1, "Nháy chậm"),
  blinkFast(2, "Nháy nhanh"),

  /// Nháy N lần rồi nghỉ, N = số ngăn (1–3) — chỉ ngăn trong khay nhiều ngăn.
  count1(3, "Nháy 1 lần"),
  count2(4, "Nháy 2 lần"),
  count3(5, "Nháy 3 lần");

  final int code;
  final String label;
  const LedEffect(this.code, this.label);

  /// Hiệu ứng "nháy N lần" cho ngăn [compartmentIndex] (0-based).
  static LedEffect forCompartment(int compartmentIndex) =>
      switch (compartmentIndex) {
        0 => count1,
        1 => count2,
        _ => count3,
      };

  static LedEffect ofCode(int code) =>
      values.where((e) => e.code == code).firstOrNull ?? solid;

  /// LED đang sáng hay tắt sau [ms] mili-giây kể từ lúc bắt đầu (firmware dùng
  /// cùng nhịp): nháy chậm 1s, nháy nhanh 0.3s, "nháy N lần" = N xung
  /// 200ms sáng / 200ms tắt rồi nghỉ 1s.
  bool isOnAt(int ms) {
    switch (this) {
      case solid:
        return true;
      case blinkSlow:
        return ms % 1000 < 500;
      case blinkFast:
        return ms % 300 < 150;
      case count1:
      case count2:
      case count3:
        final n = code - count1.code + 1;
        final t = ms % (n * 400 + 1000);
        return t < n * 400 && t % 400 < 200;
    }
  }
}

/// Yêu cầu sáng 1 LED.
class LedRequest {
  final int ledIndex;

  /// Màu gốc ARGB (độ sáng tối đa).
  final int color;

  /// Độ sáng mong muốn / thấp nhất còn nhìn thấy (0–255, theo cảm nhận mắt).
  final int brightness;
  final int minBrightness;
  final LedEffect effect;

  const LedRequest({
    required this.ledIndex,
    required this.color,
    this.brightness = 255,
    this.minBrightness = 0,
    this.effect = LedEffect.solid,
  });
}

/// 1 LED đã tính xong, gửi thẳng xuống firmware.
class LedCommand {
  final int ledIndex;
  final int r;
  final int g;
  final int b;
  final LedEffect effect;

  /// Lượt sáng (0 = lượt đầu). Firmware luân phiên các lượt khi nguồn không
  /// đủ để sáng hết cùng lúc.
  final int group;

  const LedCommand({
    required this.ledIndex,
    required this.r,
    required this.g,
    required this.b,
    this.effect = LedEffect.solid,
    this.group = 0,
  });

  /// Dòng đỉnh (mA) của LED khi sáng.
  double currentMa(double mAPerChannel) => (r + g + b) / 255 * mAPerChannel;

  int get argb => 0xFF000000 | (r << 16) | (g << 8) | b;

  @override
  bool operator ==(Object other) =>
      other is LedCommand &&
      other.ledIndex == ledIndex &&
      other.r == r &&
      other.g == g &&
      other.b == b &&
      other.effect == effect &&
      other.group == group;

  @override
  int get hashCode => Object.hash(ledIndex, r, g, b, effect, group);

  @override
  String toString() => "LED $ledIndex ($r,$g,$b) ${effect.name} lượt $group";
}

/// Thông số điện của kho.
class LedPowerSpec {
  final double supplyCurrentA;
  final double derate;
  final int ledCount;
  final double mAPerChannel;
  final double idleMaPerLed;
  final double mcuMa;

  const LedPowerSpec({
    required this.supplyCurrentA,
    this.derate = 0.8,
    required this.ledCount,
    this.mAPerChannel = 20,
    this.idleMaPerLed = 0.6,
    this.mcuMa = 120,
  });

  /// Dòng còn lại cho LED sáng (mA).
  double get budgetMa => math.max(
    0,
    supplyCurrentA * derate * 1000 - mcuMa - idleMaPerLed * ledCount,
  );
}

/// Kết quả tính: lệnh cho từng LED + thông tin để hiển thị.
class LedPlan {
  final List<LedCommand> commands;
  final double budgetMa;

  /// Dòng nếu sáng hết ở độ sáng mong muốn cùng lúc (mA).
  final double requestedMa;

  /// Hệ số độ sáng đã áp (1 = không giảm).
  final double scale;

  /// Số lượt sáng luân phiên (1 = sáng hết cùng lúc).
  final int groupCount;

  const LedPlan({
    required this.commands,
    required this.budgetMa,
    required this.requestedMa,
    required this.scale,
    required this.groupCount,
  });

  /// Dòng đỉnh lớn nhất trong các lượt (mA, chỉ phần LED sáng).
  double peakMa(double mAPerChannel) {
    final byGroup = <int, double>{};
    for (final c in commands) {
      byGroup[c.group] = (byGroup[c.group] ?? 0) + c.currentMa(mAPerChannel);
    }
    return byGroup.values.fold(0, math.max);
  }

  bool get limited => scale < 1 || groupCount > 1;
}

/// Tính màu / độ sáng thực gửi xuống LED sao cho tổng dòng không vượt nguồn.
///
/// 1. Sáng hết ở độ sáng mong muốn nếu đủ dòng.
/// 2. Không đủ: giảm đều độ sáng mọi LED, miễn là LED nào cũng còn ≥ độ sáng
///    thấp nhất của nó.
/// 3. Vẫn không được: chia lượt sáng luân phiên, mỗi lượt vừa nguồn.
class LedPlanner {
  static const gamma = 2.2;

  /// Kênh màu sau khi áp độ sáng theo cảm nhận mắt (gamma).
  static int _channel(int value, double brightness) {
    if (brightness <= 0) return 0;
    final factor = math.pow(brightness.clamp(0, 255) / 255, gamma);
    return (value * factor).round().clamp(0, 255);
  }

  static LedCommand _command(LedRequest r, double brightness, int group) =>
      LedCommand(
        ledIndex: r.ledIndex,
        r: _channel((r.color >> 16) & 0xFF, brightness),
        g: _channel((r.color >> 8) & 0xFF, brightness),
        b: _channel(r.color & 0xFF, brightness),
        effect: r.effect,
        group: group,
      );

  static LedPlan plan(List<LedRequest> requests, LedPowerSpec spec) {
    // Mỗi LED chỉ 1 yêu cầu (yêu cầu sau ghi đè)
    final byLed = <int, LedRequest>{
      for (final r in requests)
        if (r.ledIndex >= 0 && r.ledIndex < spec.ledCount) r.ledIndex: r,
    };
    final list = byLed.values.toList()
      ..sort((a, b) => a.ledIndex.compareTo(b.ledIndex));
    final budget = spec.budgetMa;
    double current(LedRequest r, double brightness) =>
        _command(r, brightness, 0).currentMa(spec.mAPerChannel);

    final requested = list.fold<double>(
      0,
      (sum, r) => sum + current(r, r.brightness.toDouble()),
    );

    if (requested <= budget || list.isEmpty) {
      return LedPlan(
        commands: [
          for (final r in list) _command(r, r.brightness.toDouble(), 0),
        ],
        budgetMa: budget,
        requestedMa: requested,
        scale: 1,
        groupCount: 1,
      );
    }

    // Dòng tỉ lệ với brightness^gamma => độ sáng nhân với scale^(1/gamma)
    final scale = budget / requested;
    final brightnessScale = math.pow(scale, 1 / gamma).toDouble();
    final fitsAll = list.every(
      (r) => r.brightness * brightnessScale >= r.minBrightness,
    );
    if (fitsAll) {
      final commands = [
        for (final r in list) _command(r, r.brightness * brightnessScale, 0),
      ];
      return LedPlan(
        commands: commands,
        budgetMa: budget,
        requestedMa: requested,
        scale: scale,
        groupCount: 1,
      );
    }

    // Chia lượt: xếp LED vào lượt đầu tiên còn đủ dòng (first-fit, LED tốn
    // dòng nhất xếp trước). LED tự nó đã vượt nguồn thì giảm sáng cho vừa.
    final sorted = [...list]
      ..sort(
        (a, b) => current(
          b,
          b.brightness.toDouble(),
        ).compareTo(current(a, a.brightness.toDouble())),
      );
    final groupLoad = <double>[];
    final commands = <LedCommand>[];
    var minScale = 1.0;
    for (final r in sorted) {
      var brightness = r.brightness.toDouble();
      var need = current(r, brightness);
      if (need > budget && need > 0) {
        final s = budget / need;
        minScale = math.min(minScale, s);
        brightness *= math.pow(s, 1 / gamma);
        need = current(r, brightness);
      }
      var group = groupLoad.indexWhere((load) => load + need <= budget);
      if (group < 0) {
        groupLoad.add(0);
        group = groupLoad.length - 1;
      }
      groupLoad[group] += need;
      commands.add(_command(r, brightness, group));
    }
    commands.sort((a, b) => a.ledIndex.compareTo(b.ledIndex));
    return LedPlan(
      commands: commands,
      budgetMa: budget,
      requestedMa: requested,
      scale: minScale,
      groupCount: groupLoad.length,
    );
  }
}
