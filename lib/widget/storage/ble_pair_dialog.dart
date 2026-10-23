import 'dart:async';

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/notifier/led_notifier.dart';
import 'package:component_companion/service/led/ble_led_controller.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';

/// Dò bộ điều khiển LED (ESP32 quảng bá dịch vụ kho thông minh) và ghép với kho.
class BlePairDialog extends HookConsumerWidget {
  final Storage storage;

  const BlePairDialog({super.key, required this.storage});

  static Future<void> show(BuildContext context, Storage storage) => showDialog(
    context: context,
    builder: (_) => BlePairDialog(storage: storage),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = useState<Map<String, BleDevice>>({});
    final error = useState<String?>(null);
    final scanning = useState(false);

    useEffect(() {
      final sub = UniversalBle.scanStream.listen((d) {
        devices.value = {...devices.value, d.deviceId: d};
      });
      () async {
        try {
          final state = await UniversalBle.getBluetoothAvailabilityState();
          if (state != AvailabilityState.poweredOn) {
            error.value = "Bluetooth chưa bật (${state.name})";
            return;
          }
          scanning.value = true;
          await UniversalBle.startScan(
            scanFilter: ScanFilter(withServices: [KhoLedUuids.service]),
          );
        } catch (e) {
          error.value = "Không dò được: $e";
          scanning.value = false;
        }
      }();
      return () {
        sub.cancel();
        UniversalBle.stopScan().catchError((_) {});
      };
    }, const []);

    Future<void> pair(BleDevice? device) async {
      await UniversalBle.stopScan().catchError((_) {});
      if (!context.mounted) return;
      final repo = ref.read(storageRepositoryProvider);
      final next = repo.get(storage.id);
      if (next == null) return;
      next.bleDeviceId = device?.deviceId ?? "";
      next.bleName = device == null ? "" : (device.name ?? device.deviceId);
      final ok = await repo.update(next).withToast(context);
      if (ok != null && context.mounted) {
        Navigator.pop(context);
        AppSnackBar.show(
          context,
          message: device == null
              ? "Đã bỏ ghép — kho dùng chế độ giả lập"
              : "Đã ghép ${next.bleName} với kho '${storage.name}'",
          type: SnackBarType.success,
        );
      }
    }

    final list = devices.value.values.toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return AppAlertDialog(
      title: "Bộ điều khiển LED",
      cancelLabel: "Đóng",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            storage.bleDeviceId.isEmpty
                ? "Kho '${storage.name}' đang chạy giả lập (chưa ghép)."
                : "Đang ghép: ${storage.bleName} (${storage.bleDeviceId})",
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (scanning.value)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.value ??
                      (list.isEmpty
                          ? "Đang dò thiết bị \"KhoLED-…\" gần đây…"
                          : "Bấm vào thiết bị để ghép"),
                  style: TextStyle(
                    color: error.value == null ? null : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final d in list)
                  Card(
                    elevation: 0,
                    color: d.deviceId == storage.bleDeviceId
                        ? AppColors.primarySoft
                        : AppColors.background,
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth_rounded),
                      title: Text(d.name ?? "(không tên)"),
                      subtitle: Text(
                        "${d.deviceId}${d.rssi == null ? "" : " · ${d.rssi} dBm"}",
                      ),
                      onTap: () => pair(d),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (storage.bleDeviceId.isNotEmpty)
          AppButton(
            label: "Bỏ ghép",
            variant: ButtonVariant.danger,
            size: ButtonSize.small,
            onPressed: () => pair(null),
          ),
      ],
    );
  }
}

/// Thử kết nối bộ điều khiển đã ghép (PING) và báo phiên bản firmware.
Future<void> pingController(
  BuildContext context,
  WidgetRef ref,
  Storage storage,
) async {
  final controller = ref.read(ledControllerProvider(storage.bleDeviceId));
  if (controller is! BleLedController) {
    AppSnackBar.show(
      context,
      message: "Kho chưa ghép bộ điều khiển (đang giả lập)",
      type: SnackBarType.info,
    );
    return;
  }
  AppSnackBar.show(context, message: "Đang kết nối ${storage.bleName}…");
  final watch = Stopwatch()..start();
  final info = await controller.ping().withToast(context);
  if (info == null || !context.mounted) return;
  AppSnackBar.show(
    context,
    message:
        "${storage.bleName}: firmware ${info.firmware}, ${info.ledCount} LED "
        "(${watch.elapsedMilliseconds} ms)",
    type: SnackBarType.success,
    duration: const Duration(seconds: 4),
  );
}
