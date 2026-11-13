import 'dart:typed_data';

import 'package:component_companion/util/led_plan.dart';
import 'package:component_companion/util/led_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List status(List<int> body) =>
    Uint8List.fromList([...body, LedProtocol.crc8(body)]);

void main() {
  test("wire bọc 0xA5 + độ dài", () {
    final f = LedProtocol.ping(3);
    final w = LedProtocol.wire(f);
    expect(w, [0xA5, f.length, ...f]);
  });

  test("chunks: khung 237 byte + 2 chia 12 đoạn ≤ 20 và ghép lại đúng", () {
    final commands = [
      for (var i = 0; i < LedProtocol.maxLedsPerShow; i++)
        LedCommand(ledIndex: i, r: 0, g: 0, b: 255),
    ];
    final frame = LedProtocol.show(0, commands, timeoutS: 30);
    final w = LedProtocol.wire(frame);
    expect(frame.length, 237);
    expect(w.length, 239);
    final parts = LedProtocol.chunks(w);
    expect(parts.length, 12);
    expect(parts.every((p) => p.length <= 20), isTrue);
    expect([for (final p in parts) ...p], w);
    expect(LedProtocol.chunks(const []), isEmpty);
  });

  group("LedStatusParser", () {
    final ok = status([1, 0x81, 7, 0, 0, 1, 60]); // PING có extra
    final ok2 = status([1, 0x90, 8, 0]);

    test("nguyên khung, PING có extra", () {
      final out = LedStatusParser().add(LedProtocol.wire(ok));
      expect(out, [ok]);
      expect(out.single[3], 0);
      expect(out.single.sublist(4, out.single.length - 1), [0, 1, 60]);
    });

    test("chia từng byte", () {
      final p = LedStatusParser();
      final out = <Uint8List>[];
      for (final b in LedProtocol.wire(ok)) {
        out.addAll(p.add([b]));
      }
      expect(out, [ok]);
    });

    test("2 khung gộp 1 notify", () {
      final out = LedStatusParser().add([
        ...LedProtocol.wire(ok),
        ...LedProtocol.wire(ok2),
      ]);
      expect(out, [ok, ok2]);
    });

    test("rác đằng trước bị bỏ", () {
      final out = LedStatusParser().add([
        0x00,
        0x13,
        0x77,
        ...LedProtocol.wire(ok),
      ]);
      expect(out, [ok]);
    });

    test("sai crc bị bỏ, khung sau vẫn nhận", () {
      final bad = Uint8List.fromList(ok)..[3] = 1;
      final out = LedStatusParser().add([
        ...LedProtocol.wire(bad),
        ...LedProtocol.wire(ok2),
      ]);
      expect(out, [ok2]);
    });

    test("độ dài sai thì hồi phục", () {
      final p = LedStatusParser();
      // 0xA5 với độ dài 2 (< 4) và 0xFF (> 240) đều bị bỏ
      final out = p.add([0xA5, 0x02, 0xA5, 0xFF, ...LedProtocol.wire(ok)]);
      expect(out, [ok]);
      expect(p.add(LedProtocol.wire(ok2)), [ok2]);
    });
  });
}
