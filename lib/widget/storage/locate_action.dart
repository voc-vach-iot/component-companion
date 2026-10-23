import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/notifier/led_notifier.dart';
import 'package:component_companion/service/led/locate_planner.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Sáng LED các ngăn đang cất [variants] rồi báo kết quả (kèm nút mở sơ đồ
/// kho để xem). Biến thể trùng chỉ tính 1 lần.
Future<LocateResult?> locateVariants(
  BuildContext context,
  WidgetRef ref,
  List<ComponentVariant> variants,
) async {
  final seen = <int>{};
  final targets = [
    for (final v in variants)
      if (seen.add(v.id)) LocateTarget(v),
  ];
  if (targets.isEmpty) return null;
  final result = await ref
      .read(ledSessionsProvider.notifier)
      .locate(targets)
      .withToast(context);
  if (result == null || !context.mounted) return result;

  final missing = result.misses;
  final parts = [
    if (result.litCount > 0)
      "Đang sáng ${result.litCount} ngăn"
          "${result.sessions.any((s) => s.simulated) ? " (giả lập)" : ""}",
    if (missing.isNotEmpty)
      missing.length == 1
          ? "${missing.single.variant.fullLabel}: ${missing.single.reason}"
          : "${missing.length} linh kiện chưa sáng được "
                "(${missing.where((m) => m.reason == "Chưa có chỗ cất").length} chưa có chỗ cất)",
  ];
  AppSnackBar.show(
    context,
    message: parts.join(" · "),
    type: result.litCount > 0 ? SnackBarType.success : SnackBarType.info,
    duration: const Duration(seconds: 5),
    actionLabel: result.litCount > 0 ? "Xem kho" : null,
    onAction: result.litCount > 0
        ? () {
            ref
                .read(storageFocusProvider.notifier)
                .show(result.sessions.first.storageId);
            context.go("/storage");
          }
        : null,
  );
  return result;
}
