import 'dart:typed_data';

import 'package:component_companion/service/led/ble_led_controller.dart';
import 'package:component_companion/util/led_order.dart';
import 'package:component_companion/util/led_plan.dart';
import 'package:component_companion/util/led_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const blue = 0xFF0000FF;
  const white = 0xFFFFFFFF;

  LedPowerSpec spec(double amps, {int leds = 60}) => LedPowerSpec(
    supplyCurrentA: amps,
    ledCount: leds,
    mAPerChannel: 20,
    idleMaPerLed: 0.6,
    mcuMa: 120,
  );

  group("Giới hạn dòng", () {
    test("ngân sách = nguồn × derate − mạch − LED tắt", () {
      // 2400 × 0.8 − 120 − 0.6 × 60 = 1764
      expect(spec(2.4).budgetMa, closeTo(1764, 0.001));
    });

    test("60 khay A6 xanh dương trên nguồn 5V 2.4A: không giảm sáng", () {
      final plan = LedPlanner.plan([
        for (var i = 0; i < 60; i++) LedRequest(ledIndex: i, color: blue),
      ], spec(2.4));
      expect(plan.scale, 1);
      expect(plan.groupCount, 1);
      expect(plan.commands.every((c) => c.b == 255), isTrue);
      expect(plan.peakMa(20), closeTo(1200, 0.001));
    });

    test("trắng toàn dải: giảm đều độ sáng cho vừa nguồn", () {
      final plan = LedPlanner.plan([
        for (var i = 0; i < 60; i++)
          LedRequest(ledIndex: i, color: white, minBrightness: 30),
      ], spec(2.4));
      expect(plan.groupCount, 1);
      expect(plan.scale, lessThan(1));
      expect(plan.peakMa(20), lessThanOrEqualTo(plan.budgetMa + 60));
      expect(plan.commands.first.r, plan.commands.first.b);
    });

    test("độ sáng tối thiểu cao: chia lượt, mỗi lượt vừa nguồn", () {
      final plan = LedPlanner.plan([
        for (var i = 0; i < 60; i++)
          LedRequest(ledIndex: i, color: white, minBrightness: 250),
      ], spec(2.4));
      expect(plan.groupCount, greaterThan(1));
      for (var g = 0; g < plan.groupCount; g++) {
        final load = plan.commands
            .where((c) => c.group == g)
            .fold<double>(0, (s, c) => s + c.currentMa(20));
        expect(load, lessThanOrEqualTo(plan.budgetMa + 0.001));
      }
      // LED không bị giảm sáng
      expect(plan.commands.every((c) => c.r == 255), isTrue);
    });

    test("LED ngoài dải bị bỏ, LED trùng giữ yêu cầu sau", () {
      final plan = LedPlanner.plan([
        const LedRequest(ledIndex: 3, color: blue),
        const LedRequest(ledIndex: 3, color: white),
        const LedRequest(ledIndex: 99, color: blue),
      ], spec(2.4));
      expect(plan.commands, hasLength(1));
      expect(plan.commands.single.r, 255);
    });

    test("độ sáng theo gamma", () {
      final plan = LedPlanner.plan([
        const LedRequest(ledIndex: 0, color: blue, brightness: 128),
      ], spec(2.4));
      // (128/255)^2.2 × 255 ≈ 56
      expect(plan.commands.single.b, inInclusiveRange(54, 58));
    });
  });

  group("Giao thức", () {
    test("crc8 đa thức 0x07", () {
      // Giá trị kiểm tra chuẩn của CRC-8/SMBUS cho "123456789"
      expect(LedProtocol.crc8("123456789".codeUnits), 0xF4);
    });

    test("SHOW đọc lại đúng", () {
      const commands = [
        LedCommand(ledIndex: 2, r: 0, g: 0, b: 255, effect: LedEffect.count2),
        LedCommand(ledIndex: 7, r: 10, g: 20, b: 30, group: 1),
      ];
      final frame = LedProtocol.show(5, commands, timeoutS: 60, rotateMs: 2500);
      expect(LedProtocol.isValid(frame), isTrue);
      final parsed = LedProtocol.parseShow(frame)!;
      expect(parsed.timeoutS, 60);
      expect(parsed.rotateMs, 2500);
      expect(parsed.commands, commands);

      final broken = [...frame]..[9] ^= 1;
      expect(LedProtocol.isValid(broken), isFalse);
    });

    test("60 LED tách thành SHOW + APPEND vừa MTU", () {
      final commands = [
        for (var i = 0; i < 60; i++) LedCommand(ledIndex: i, r: 0, g: 0, b: 9),
      ];
      final frames = LedProtocol.showFrames(0, commands, timeoutS: 30);
      expect(frames, hasLength(2));
      expect(frames[0][1], LedProtocol.cmdShow);
      expect(frames[1][1], LedProtocol.cmdAppend);
      expect(frames.every((f) => f.length <= 244), isTrue);
      expect(frames.every(LedProtocol.isValid), isTrue);
    });

    test("CONFIG", () {
      final frame = LedProtocol.config(
        1,
        ledCount: 60,
        colorOrder: "grb",
        maxMa: 1764,
        mAPerChannel: 20,
      );
      expect(frame.sublist(0, 8), [1, 0x02, 1, 60, 0, 0x06, 0xE4, 20]);
      expect(LedProtocol.isValid(frame), isTrue);
    });
  });

  group("Thứ tự LED", () {
    // 2 hàng × 3 khay 100×50, hàng dưới hơi lệch
    final trays = <TrayRect>[
      (id: 1, x: 0, y: 0, w: 100, h: 50),
      (id: 2, x: 100, y: 2, w: 100, h: 50),
      (id: 3, x: 200, y: 0, w: 100, h: 50),
      (id: 4, x: 0, y: 60, w: 100, h: 50),
      (id: 5, x: 100, y: 58, w: 100, h: 50),
      (id: 6, x: 200, y: 61, w: 100, h: 50),
    ];

    test("theo hàng / zig-zag", () {
      expect(sortTraysForLed(trays, LedOrder.rows), [1, 2, 3, 4, 5, 6]);
      expect(sortTraysForLed(trays, LedOrder.snakeRows), [1, 2, 3, 6, 5, 4]);
    });

    test("theo cột / zig-zag", () {
      expect(sortTraysForLed(trays, LedOrder.columns), [1, 4, 2, 5, 3, 6]);
      expect(sortTraysForLed(trays, LedOrder.snakeColumns), [1, 4, 5, 2, 3, 6]);
    });
  });

  group("Trạng thái từ bộ điều khiển", () {
    Uint8List frame(List<int> body) =>
        Uint8List.fromList([...body, LedProtocol.crc8(body)]);

    test("PING trả phiên bản + số LED", () {
      final s = LedLinkStatus.parse(frame([1, 0x81, 7, 0, 0, 1, 60]))!;
      expect(s.cmd, LedProtocol.cmdPing);
      expect(s.seq, 7);
      expect(s.code, LedLinkStatus.ok);
      expect(s.extra, [0, 1, 60]);
    });

    test("lệnh lạ / khung hỏng", () {
      final s = LedLinkStatus.parse(frame([1, 0x90, 3, 3]))!;
      expect(s.code, LedLinkStatus.unknown);
      final broken = frame([1, 0x90, 3, 3])..[3] = 0;
      expect(LedLinkStatus.parse(broken), isNull);
      // Không có bit 0x80 => không phải trạng thái
      expect(LedLinkStatus.parse(frame([1, 0x10, 3, 0])), isNull);
    });
  });

  test("nhịp nháy khớp firmware", () {
    expect(LedEffect.solid.isOnAt(12345), isTrue);
    expect(LedEffect.blinkSlow.isOnAt(400), isTrue);
    expect(LedEffect.blinkSlow.isOnAt(600), isFalse);
    // Nháy 2 lần: sáng 0–200, 400–600; nghỉ tới 1800
    expect([0, 300, 450, 700, 1700, 1850].map(LedEffect.count2.isOnAt), [
      true,
      false,
      true,
      false,
      false,
      true,
    ]);
  });
}
