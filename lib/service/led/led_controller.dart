import 'dart:typed_data';

import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/util/led_plan.dart';
import 'package:component_companion/util/led_protocol.dart';

/// Gửi lệnh tới bộ điều khiển LED của 1 kho.
abstract class LedController {
  /// true = không có phần cứng, chỉ hiển thị trên sơ đồ.
  bool get simulated;

  Future<void> show(Storage storage, LedPlan plan, {int rotateMs = 3000});

  Future<void> off(Storage storage);

  /// Khung CONFIG + SHOW (+ APPEND) cho [plan], dùng chung cho mọi bản.
  static List<Uint8List> framesFor(
    Storage storage,
    LedPlan plan, {
    required int seq,
    int rotateMs = 3000,
  }) => [
    LedProtocol.config(
      seq,
      ledCount: storage.ledCount,
      colorOrder: storage.colorOrder,
      maxMa: plan.budgetMa.floor(),
      mAPerChannel: storage.mAPerChannel.round(),
    ),
    ...LedProtocol.showFrames(
      seq + 1,
      plan.commands,
      timeoutS: storage.lightTimeoutS,
      rotateMs: rotateMs,
    ),
  ];
}

/// Bản giả lập: kiểm tra khung hợp lệ rồi thôi, LED chỉ vẽ trên sơ đồ kho.
class SimulatedLedController implements LedController {
  /// Các khung đã "gửi" (để test / xem log).
  final sent = <Uint8List>[];
  var _seq = 0;

  @override
  bool get simulated => true;

  @override
  Future<void> show(
    Storage storage,
    LedPlan plan, {
    int rotateMs = 3000,
  }) async {
    final frames = LedController.framesFor(
      storage,
      plan,
      seq: _seq,
      rotateMs: rotateMs,
    );
    _seq = (_seq + frames.length) & 0xFF;
    assert(frames.every(LedProtocol.isValid));
    sent.addAll(frames);
  }

  @override
  Future<void> off(Storage storage) async {
    sent.add(LedProtocol.off(_seq));
    _seq = (_seq + 1) & 0xFF;
  }
}
