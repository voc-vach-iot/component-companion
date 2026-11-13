import 'package:component_companion/service/led/ble_led_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  test("dịch lỗi BLE sang tiếng Việt", () {
    final busy = UniversalBleException(
      code: UniversalBleErrorCode.unknownError,
      message: "org.bluez.Error.Failed: Operation already in progress",
    );
    expect(describeBleError(busy), contains("đang bận"));

    final lost = UniversalBleException(
      code: UniversalBleErrorCode.writeFailed,
      message: "Not connected",
    );
    expect(describeBleError(lost), contains("Mất kết nối"));

    expect(describeBleError(lost), contains("bộ điều khiển lại gần"));
    expect(describeBleError(lost), isNot(contains("ESP32")));

    expect(describeBleError(StateError("x")), contains("Lỗi không rõ"));
  });
}
