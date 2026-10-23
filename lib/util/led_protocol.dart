import 'dart:typed_data';

import 'package:component_companion/util/led_plan.dart';

/// Khung lệnh gửi qua BLE tới ESP32-C3 (C3 chuyển nguyên khung xuống CH32V003).
///
/// `[ver][cmd][seq][payload…][crc8]`, crc8 (đa thức 0x07, giá trị đầu 0x00)
/// tính trên mọi byte trước nó. Xem `docs/kho-thong-minh.md` mục Giao thức.
class LedProtocol {
  static const version = 1;

  static const cmdPing = 0x01;
  static const cmdConfig = 0x02;
  static const cmdShow = 0x10;
  static const cmdOff = 0x11;

  /// Thêm LED vào lệnh SHOW trước đó (khi 1 khung không chứa hết).
  static const cmdAppend = 0x12;

  /// Số LED tối đa trong 1 khung SHOW (vừa MTU 247 của BLE).
  static const maxLedsPerShow = 38;

  static const colorOrders = ["GRB", "RGB", "BRG", "RBG", "GBR", "BGR"];

  static int crc8(List<int> bytes) {
    var crc = 0;
    for (final byte in bytes) {
      crc ^= byte & 0xFF;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x80) != 0
            ? ((crc << 1) ^ 0x07) & 0xFF
            : (crc << 1) & 0xFF;
      }
    }
    return crc;
  }

  static Uint8List _frame(int cmd, int seq, List<int> payload) {
    final body = [version, cmd, seq & 0xFF, ...payload];
    return Uint8List.fromList([...body, crc8(body)]);
  }

  static List<int> _u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];

  static Uint8List ping(int seq) => _frame(cmdPing, seq, const []);

  static Uint8List off(int seq) => _frame(cmdOff, seq, const []);

  /// Cấu hình dải LED: số LED, thứ tự màu, dòng tối đa cho LED sáng (mA) và
  /// dòng mỗi kênh màu (mA) để firmware tự chặn thêm 1 lớp.
  static Uint8List config(
    int seq, {
    required int ledCount,
    required String colorOrder,
    required int maxMa,
    required int mAPerChannel,
  }) {
    final order = colorOrders.indexOf(colorOrder.toUpperCase());
    return _frame(cmdConfig, seq, [
      ledCount.clamp(1, 255),
      order < 0 ? 0 : order,
      ..._u16(maxMa.clamp(0, 0xFFFF)),
      mAPerChannel.clamp(1, 255),
    ]);
  }

  /// Sáng các LED trong [commands]; tự tắt sau [timeoutS] giây, luân phiên các
  /// lượt mỗi [rotateMs] ms. Mỗi LED 6 byte: led, r, g, b, effect, group.
  static Uint8List show(
    int seq,
    List<LedCommand> commands, {
    required int timeoutS,
    int rotateMs = 3000,
  }) {
    if (commands.length > maxLedsPerShow) {
      throw ArgumentError(
        "Tối đa $maxLedsPerShow LED / khung (đang có ${commands.length})",
      );
    }
    return _frame(cmdShow, seq, [
      ..._u16(timeoutS.clamp(0, 0xFFFF)),
      ..._u16(rotateMs.clamp(0, 0xFFFF)),
      commands.length,
      for (final c in commands) ...[
        c.ledIndex,
        c.r,
        c.g,
        c.b,
        c.effect.code,
        c.group,
      ],
    ]);
  }

  /// Thêm LED vào lệnh SHOW vừa gửi (giữ nguyên hẹn giờ / chu kỳ lượt).
  static Uint8List append(int seq, List<LedCommand> commands) {
    if (commands.length > maxLedsPerShow) {
      throw ArgumentError("Tối đa $maxLedsPerShow LED / khung");
    }
    return _frame(cmdAppend, seq, [
      commands.length,
      for (final c in commands) ...[
        c.ledIndex,
        c.r,
        c.g,
        c.b,
        c.effect.code,
        c.group,
      ],
    ]);
  }

  /// SHOW + các APPEND cần thiết để gửi hết [commands]; seq tăng dần từ [seq].
  static List<Uint8List> showFrames(
    int seq,
    List<LedCommand> commands, {
    required int timeoutS,
    int rotateMs = 3000,
  }) {
    final frames = <Uint8List>[];
    for (var i = 0; i == 0 || i < commands.length; i += maxLedsPerShow) {
      final end = (i + maxLedsPerShow).clamp(0, commands.length);
      final chunk = commands.sublist(i, end);
      frames.add(
        i == 0
            ? show(seq, chunk, timeoutS: timeoutS, rotateMs: rotateMs)
            : append(seq + frames.length, chunk),
      );
    }
    return frames;
  }

  /// Kiểm tra khung (độ dài tối thiểu, phiên bản, crc).
  static bool isValid(List<int> frame) =>
      frame.length >= 4 &&
      frame[0] == version &&
      crc8(frame.sublist(0, frame.length - 1)) == frame.last;

  /// Đọc lại khung SHOW (dùng cho giả lập và test).
  static ({int timeoutS, int rotateMs, List<LedCommand> commands})? parseShow(
    List<int> frame,
  ) {
    if (!isValid(frame) || frame[1] != cmdShow || frame.length < 9) return null;
    final timeoutS = (frame[3] << 8) | frame[4];
    final rotateMs = (frame[5] << 8) | frame[6];
    final n = frame[7];
    if (frame.length != 9 + n * 6) return null;
    final commands = [
      for (var i = 0; i < n; i++)
        LedCommand(
          ledIndex: frame[8 + i * 6],
          r: frame[9 + i * 6],
          g: frame[10 + i * 6],
          b: frame[11 + i * 6],
          effect: LedEffect.ofCode(frame[12 + i * 6]),
          group: frame[13 + i * 6],
        ),
    ];
    return (timeoutS: timeoutS, rotateMs: rotateMs, commands: commands);
  }
}
