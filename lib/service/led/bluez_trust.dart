import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:flutter/foundation.dart';

/// Linux: đánh dấu thiết bị là "Trusted" trong BlueZ. Thiết bị chưa ghép bị
/// BlueZ xoá sau ~30 giây ngừng dò, lần sau phải dò lại mất vài giây; thiết bị
/// trusted được lưu lại nên các lần sau kết nối thẳng.
///
/// Lỗi ở đây không ảnh hưởng việc gửi lệnh nên chỉ ghi log.
Future<void> trustBleDevice(String deviceId) async {
  if (!Platform.isLinux) return;
  final client = BlueZClient();
  try {
    await client.connect();
    final address = deviceId.toUpperCase();
    final device = client.devices
        .where((d) => d.address.toUpperCase() == address)
        .firstOrNull;
    if (device != null && !device.trusted) await device.setTrusted(true);
  } catch (e) {
    debugPrint("BlueZ: không đánh dấu trusted được $deviceId: $e");
  } finally {
    await client.close();
  }
}
