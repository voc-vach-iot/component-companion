import 'dart:async';

import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/service/led/bluez_trust.dart';
import 'package:component_companion/service/led/led_controller.dart';
import 'package:component_companion/util/led_plan.dart';
import 'package:component_companion/util/led_protocol.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

/// Lỗi khi nói chuyện với bộ điều khiển LED qua BLE.
class LedLinkException extends AppException {
  /// Lỗi tầng BLE (mất kết nối...) nên thử lại; lỗi ESP32 / CH32 trả về thì không.
  final bool retryable;

  LedLinkException(super.message, {this.retryable = false});
}

/// UUID dịch vụ kho thông minh (khớp firmware `smart-storage/src/esp32/main.cpp`).
class KhoLedUuids {
  static const service = "6b1f0001-3c2a-4e8d-9b7e-2f6a4c1d8e01";
  static const command = "6b1f0002-3c2a-4e8d-9b7e-2f6a4c1d8e01";
  static const status = "6b1f0003-3c2a-4e8d-9b7e-2f6a4c1d8e01";
}

/// Trạng thái ESP32 gửi lại sau mỗi khung: [ver][0x80 | cmd][seq][code][...][crc].
class LedLinkStatus {
  static const ok = 0;
  static const badCrc = 1;
  static const noAck = 2;
  static const unknown = 3;

  final int cmd;
  final int seq;
  final int code;
  final Uint8List extra;

  const LedLinkStatus(this.cmd, this.seq, this.code, this.extra);

  static LedLinkStatus? parse(Uint8List data) {
    if (!LedProtocol.isValid(data) || data.length < 5) return null;
    if (data[1] & 0x80 == 0) return null;
    return LedLinkStatus(
      data[1] & 0x7F,
      data[2],
      data[3],
      data.sublist(4, data.length - 1),
    );
  }

  String get message => switch (code) {
    ok => "OK",
    badCrc => "ESP32 nhận khung hỏng (sai crc)",
    noAck => "Mạch LED (CH32V003) không trả lời — kiểm tra dây nối / nguồn",
    unknown => "ESP32 không hiểu lệnh (firmware cũ?)",
    _ => "Lỗi không rõ (mã $code)",
  };
}

/// Gửi lệnh tới ESP32-C3 qua BLE: kết nối → gửi từng khung, chờ trạng thái →
/// ngắt kết nối ngay để ESP32 quay lại ngủ.
class BleLedController implements LedController {
  final String deviceId;
  var _seq = 0;

  /// Đã đánh dấu trusted trong BlueZ (Linux) ở phiên này.
  var _trusted = false;

  /// Lần gửi trước chưa xong thì lần sau chờ (tránh 2 kết nối chồng nhau).
  Future<void> _last = Future.value();

  BleLedController(this.deviceId);

  @override
  bool get simulated => false;

  @override
  Future<void> show(Storage storage, LedPlan plan, {int rotateMs = 3000}) {
    final frames = LedController.framesFor(
      storage,
      plan,
      seq: _seq,
      rotateMs: rotateMs,
    );
    _seq = (_seq + frames.length) & 0xFF;
    return _queue(frames);
  }

  @override
  Future<void> off(Storage storage) {
    final frame = LedProtocol.off(_seq);
    _seq = (_seq + 1) & 0xFF;
    return _queue([frame]);
  }

  /// PING: trả về (phiên bản firmware, số LED đã cấu hình).
  Future<({String firmware, int ledCount})> ping() async {
    final frame = LedProtocol.ping(_seq);
    _seq = (_seq + 1) & 0xFF;
    late LedLinkStatus status;
    await _queue([frame], onStatus: (s) => status = s);
    if (status.extra.length < 3) return (firmware: "?", ledCount: 0);
    return (
      firmware: "${status.extra[0]}.${status.extra[1]}",
      ledCount: status.extra[2],
    );
  }

  Future<void> _queue(
    List<Uint8List> frames, {
    void Function(LedLinkStatus status)? onStatus,
  }) {
    final run = _last
        .catchError((_) {})
        .then((_) => _send(frames, onStatus: onStatus));
    _last = run;
    return run;
  }

  /// Kết nối (dò lại thiết bị nếu BlueZ / Windows chưa biết tới nó).
  Future<void> _connect() async {
    try {
      await UniversalBle.connect(deviceId, timeout: const Duration(seconds: 8));
      return;
    } catch (e) {
      // Thiết bị chưa có trong bộ nhớ đệm của hệ thống => dò 6 giây rồi thử lại
      debugPrint("BLE $deviceId: kết nối lỗi ($e) => dò lại");
    }
    final found = Completer<void>();
    final sub = UniversalBle.scanStream.listen((d) {
      if (d.deviceId == deviceId && !found.isCompleted) found.complete();
    });
    try {
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [KhoLedUuids.service]),
      );
      await found.future.timeout(const Duration(seconds: 6));
    } on TimeoutException {
      throw LedLinkException(
        "Không thấy bộ điều khiển LED — ESP32 có đang bật và ở gần không?",
      );
    } finally {
      await sub.cancel();
      await UniversalBle.stopScan().catchError((_) {});
    }
    await UniversalBle.connect(deviceId, timeout: const Duration(seconds: 8));
  }

  Future<void> _send(
    List<Uint8List> frames, {
    void Function(LedLinkStatus status)? onStatus,
  }) async {
    // BlueZ đôi khi báo "Not connected" ở lần ghi đầu ngay sau khi kết nối
    // => thử lại cả phiên 1 lần
    try {
      await _session(frames, onStatus: onStatus);
    } on LedLinkException catch (e) {
      if (!e.retryable) rethrow;
      debugPrint("BLE: ${e.message} => thử lại");
      await _session(frames, onStatus: onStatus);
    }
  }

  Future<void> _session(
    List<Uint8List> frames, {
    void Function(LedLinkStatus status)? onStatus,
  }) async {
    final watch = Stopwatch()..start();
    void step(String name) =>
        debugPrint("BLE $deviceId: $name sau ${watch.elapsedMilliseconds} ms");
    // Trạng thái chờ theo seq; listener điền vào khi ESP32 gửi notify
    final waiting = <int, Completer<LedLinkStatus>>{};
    StreamSubscription<Uint8List>? sub;
    try {
      await _connect();
      step("kết nối");
      if (!_trusted) {
        _trusted = true;
        await trustBleDevice(deviceId);
      }
      await UniversalBle.discoverServices(deviceId);
      step("tìm dịch vụ");
      await UniversalBle.requestMtu(deviceId, 247).catchError((_) => 23);
      sub = UniversalBle.characteristicValueStream(deviceId, KhoLedUuids.status)
          .listen((data) {
            final s = LedLinkStatus.parse(data);
            final c = s == null ? null : waiting.remove(s.seq);
            if (c != null && !c.isCompleted) c.complete(s);
          });
      await UniversalBle.subscribeNotifications(
        deviceId,
        KhoLedUuids.service,
        KhoLedUuids.status,
      );
      step("đăng ký trạng thái");
      for (final frame in frames) {
        final reply = waiting[frame[2]] = Completer<LedLinkStatus>();
        await UniversalBle.write(
          deviceId,
          KhoLedUuids.service,
          KhoLedUuids.command,
          frame,
        );
        final LedLinkStatus status;
        try {
          // ESP32 có thể thử đánh thức CH32 2 lần × 60ms
          status = await reply.future.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          throw LedLinkException("ESP32 không trả lời lệnh");
        }
        if (status.code != LedLinkStatus.ok) {
          throw LedLinkException(status.message);
        }
        onStatus?.call(status);
      }
      step("xong ${frames.length} khung");
    } on AppException {
      rethrow;
    } catch (e) {
      throw LedLinkException("Lỗi BLE: $e", retryable: true);
    } finally {
      await sub?.cancel();
      await UniversalBle.disconnect(deviceId).catchError((_) {});
    }
  }
}
