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
  /// Lỗi tầng BLE (mất kết nối...) nên thử lại; lỗi bộ điều khiển trả về thì không.
  final bool retryable;

  LedLinkException(super.message, {this.retryable = false});
}

/// Dịch lỗi BLE (thư viện / BlueZ, tiếng Anh) sang câu dễ hiểu kèm gợi ý.
String describeBleError(Object e) {
  final raw = e is UniversalBleException ? "${e.message} ${e.details}" : "$e";
  final text = raw.toLowerCase();
  final code = e is UniversalBleException ? e.code : null;
  bool has(String s) => text.contains(s);

  final reason = switch (code) {
    _
        when has("already in progress") ||
            code == UniversalBleErrorCode.connectionInProgress ||
            code == UniversalBleErrorCode.operationInProgress =>
      "Bluetooth đang bận xử lý lần kết nối trước (đang ngắt hoặc đang kết nối dở). Đợi vài giây rồi thử lại",
    _
        when has("not connected") ||
            code == UniversalBleErrorCode.deviceDisconnected ||
            code == UniversalBleErrorCode.connectionTerminated =>
      "Mất kết nối với bộ điều khiển giữa chừng — tín hiệu yếu, hãy đưa bộ điều khiển lại gần hoặc tránh vật cản kim loại",
    _
        when has("timeout") ||
            has("timed out") ||
            code == UniversalBleErrorCode.connectionTimeout ||
            code == UniversalBleErrorCode.operationTimeout =>
      "Quá thời gian chờ — bộ điều khiển không phản hồi (đang ngủ, tắt nguồn hoặc ở quá xa)",
    _
        when has("connection abort") ||
            has("le-connection-abort") ||
            code == UniversalBleErrorCode.connectionFailed ||
            code == UniversalBleErrorCode.connectionRejected =>
      "Kết nối bị hủy — tín hiệu yếu hoặc module BLE đang được thiết bị khác giữ kết nối",
    _
        when has("does not exist") ||
            has("not found") ||
            code == UniversalBleErrorCode.deviceNotFound =>
      "Không tìm thấy bộ điều khiển — bộ điều khiển có đang bật và ở gần không?",
    UniversalBleErrorCode.serviceNotFound ||
    UniversalBleErrorCode.characteristicNotFound =>
      "Thiết bị không có dịch vụ kho thông minh (sai thiết bị)",
    UniversalBleErrorCode.bluetoothNotAvailable ||
    UniversalBleErrorCode.bluetoothNotEnabled =>
      "Bluetooth của máy tính đang tắt hoặc không khả dụng",
    UniversalBleErrorCode.bluetoothNotAllowed ||
    UniversalBleErrorCode.bluetoothUnauthorized =>
      "App chưa được cấp quyền Bluetooth",
    UniversalBleErrorCode.writeFailed => "Gửi lệnh thất bại",
    _ => "Lỗi không rõ",
  };
  return "Lỗi BLE: $reason";
}

/// UUID của module JDY-23 (FFE0 là UUID chung của mọi module JDY nên chưa chắc
/// có trong gói quảng bá; dò thiết bị theo tên [namePrefix]). Lệnh và trạng
/// thái dùng chung 1 characteristic (write + notify).
class KhoLedUuids {
  static const service = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const data = "0000ffe1-0000-1000-8000-00805f9b34fb";

  /// Tiền tố tên quảng bá `KhoLED-XXXX`.
  static const namePrefix = "KhoLED";

  /// Bộ lọc dò thiết bị theo tên.
  static ScanFilter get scanFilter => ScanFilter(withNamePrefix: [namePrefix]);
}

/// Trạng thái bộ điều khiển gửi lại sau mỗi khung: [ver][0x80 | cmd][seq][code][...][crc].
class LedLinkStatus {
  static const ok = 0;
  static const badCrc = 1;
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
    badCrc => "Bộ điều khiển nhận khung hỏng (sai crc)",
    unknown => "Bộ điều khiển không hiểu lệnh (firmware cũ?)",
    _ => "Lỗi không rõ (mã $code)",
  };
}

/// Gửi lệnh tới module JDY-23 qua BLE: kết nối → gửi từng khung (bọc 0xA5 +
/// độ dài, chia ≤ 20 byte), chờ trạng thái → ngắt kết nối sau vài giây rảnh.
class BleLedController implements LedController {
  final String deviceId;
  var _seq = 0;

  /// Đã đánh dấu trusted trong BlueZ (Linux) ở phiên này.
  var _trusted = false;

  /// Lần gửi trước chưa xong thì lần sau chờ (tránh 2 kết nối chồng nhau).
  Future<void> _last = Future.value();

  /// Thời gian giữ kết nối sau lệnh cuối trước khi ngắt kết nối.
  static const idleDisconnect = Duration(seconds: 6);

  /// Đã kết nối + đăng ký trạng thái, dùng lại được cho lệnh sau.
  var _ready = false;
  StreamSubscription<Uint8List>? _statusSub;
  Timer? _idle;

  /// Trạng thái chờ theo seq; listener điền vào khi thiết bị gửi notify
  final _waiting = <int, Completer<LedLinkStatus>>{};

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
    bool close = false,
  }) {
    final run = _last
        .catchError((_) {})
        .then((_) => close ? _close() : _send(frames, onStatus: onStatus));
    _last = run;
    return run;
  }

  /// Ngắt kết nối còn treo với [deviceId]. Kết nối quá giờ của app vẫn có thể
  /// hoàn tất trong BlueZ về sau; module BLE chỉ nhận 1 kết nối và ngừng quảng bá
  /// khi đã có, nên kết nối treo làm mọi máy khác không thấy / không nối được.
  static Future<void> releaseLink(String deviceId) async {
    if (deviceId.isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    try {
      final state = await UniversalBle.getConnectionState(deviceId);
      if (state == BleConnectionState.disconnected) return;
      debugPrint("BLE $deviceId: còn kết nối treo ($state) => ngắt");
      await UniversalBle.disconnect(
        deviceId,
        timeout: const Duration(seconds: 3),
      );
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 500));
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
    // Hủy lần kết nối dở của BlueZ, nếu không lần sau báo "already in progress"
    await releaseLink(deviceId);
    final found = Completer<void>();
    final sub = UniversalBle.scanStream.listen((d) {
      if (d.deviceId == deviceId && !found.isCompleted) found.complete();
    });
    try {
      await UniversalBle.startScan(scanFilter: KhoLedUuids.scanFilter);
      await found.future.timeout(const Duration(seconds: 6));
    } on TimeoutException {
      throw LedLinkException(
        "Không thấy bộ điều khiển LED — bộ điều khiển có đang bật và ở gần không?",
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
    _idle?.cancel();
    // BlueZ đôi khi báo "Not connected" / "Operation already in progress" ở lần
    // đầu => đóng hẳn, chờ BlueZ dọn xong rồi thử lại cả phiên 1 lần
    try {
      await _session(frames, onStatus: onStatus);
    } on LedLinkException catch (e) {
      if (!e.retryable) {
        _scheduleIdle();
        rethrow;
      }
      debugPrint("BLE: ${e.message} => thử lại");
      await _close();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      try {
        await _session(frames, onStatus: onStatus);
      } on LedLinkException {
        await _close();
        rethrow;
      }
    }
    _scheduleIdle();
  }

  /// Giữ kết nối vài giây cho các lệnh liền nhau (kết nối + tìm dịch vụ mất
  /// 1-3 giây mỗi lần), rồi ngắt để module BLE quảng bá lại.
  void _scheduleIdle() {
    _idle?.cancel();
    _idle = Timer(idleDisconnect, () => _queue([], close: true));
  }

  /// Ngắt kết nối và đợi BlueZ báo đã ngắt (ngắt chưa xong mà kết nối lại sẽ
  /// bị "Operation already in progress").
  Future<void> _close() async {
    _idle?.cancel();
    final sub = _statusSub;
    _statusSub = null;
    _ready = false;
    _waiting.clear();
    await sub?.cancel();
    try {
      await UniversalBle.disconnect(
        deviceId,
        timeout: const Duration(seconds: 5),
      );
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  /// Kết nối, tìm dịch vụ, đăng ký trạng thái (bỏ qua nếu còn kết nối).
  Future<void> _open(Stopwatch watch) async {
    void step(String name) =>
        debugPrint("BLE $deviceId: $name sau ${watch.elapsedMilliseconds} ms");
    await _connect();
    step("kết nối");
    if (!_trusted) {
      _trusted = true;
      await trustBleDevice(deviceId);
    }
    await UniversalBle.discoverServices(deviceId);
    step("tìm dịch vụ");
    // Parser mới mỗi lần mở: bỏ byte dở của phiên trước
    final parser = LedStatusParser();
    _statusSub =
        UniversalBle.characteristicValueStream(
          deviceId,
          KhoLedUuids.data,
        ).listen((data) {
          for (final frame in parser.add(data)) {
            final s = LedLinkStatus.parse(frame);
            final c = s == null ? null : _waiting.remove(s.seq);
            if (c != null && !c.isCompleted) c.complete(s);
          }
        });
    await UniversalBle.subscribeNotifications(
      deviceId,
      KhoLedUuids.service,
      KhoLedUuids.data,
    );
    // Để yêu cầu đăng ký kịp tới module trước khi gửi lệnh đầu tiên
    await Future<void>.delayed(const Duration(milliseconds: 150));
    step("đăng ký trạng thái");
    _ready = true;
  }

  Future<void> _session(
    List<Uint8List> frames, {
    void Function(LedLinkStatus status)? onStatus,
  }) async {
    final watch = Stopwatch()..start();
    try {
      if (_ready) {
        final state = await UniversalBle.getConnectionState(deviceId);
        if (state != BleConnectionState.connected) await _close();
      }
      if (!_ready) await _open(watch);
      for (final frame in frames) {
        final reply = _waiting[frame[2]] = Completer<LedLinkStatus>();
        // Ghi tuần tự từng đoạn ≤ 20 byte, có phản hồi
        for (final part in LedProtocol.chunks(LedProtocol.wire(frame))) {
          await UniversalBle.write(
            deviceId,
            KhoLedUuids.service,
            KhoLedUuids.data,
            part,
          );
        }
        final LedLinkStatus status;
        try {
          status = await reply.future.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          throw LedLinkException(
            "Bộ điều khiển nhận lệnh nhưng không báo lại — tín hiệu yếu hoặc CH32 không phản hồi?",
            retryable: true,
          );
        }
        if (status.code != LedLinkStatus.ok) {
          throw LedLinkException(status.message);
        }
        onStatus?.call(status);
      }
      debugPrint(
        "BLE $deviceId: xong ${frames.length} khung sau "
        "${watch.elapsedMilliseconds} ms",
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw LedLinkException(describeBleError(e), retryable: true);
    }
  }
}
