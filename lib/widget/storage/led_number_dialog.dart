import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/notifier/storage_undo_notifier.dart';
import 'package:component_companion/util/led_order.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Đánh số LED cho các khay đang chọn: LED bắt đầu, góc bắt đầu, hướng chạy.
Future<void> showLedNumberDialog(
  BuildContext context,
  WidgetRef ref,
  Storage storage,
  List<StorageTray> selection,
  List<StorageTray> allTrays,
) => showDialog(
  context: context,
  builder: (_) => _LedNumberDialog(
    storage: storage,
    selection: selection,
    allTrays: allTrays,
  ),
);

class _LedNumberDialog extends HookConsumerWidget {
  final Storage storage;
  final List<StorageTray> selection;
  final List<StorageTray> allTrays;

  const _LedNumberDialog({
    required this.storage,
    required this.selection,
    required this.allTrays,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = selection.map((t) => t.id).toSet();
    final maxOutside = allTrays
        .where((t) => !ids.contains(t.id) && t.hasLed)
        .fold<int>(-1, (m, t) => t.ledIndex > m ? t.ledIndex : m);
    final startCtrl = useTextEditingController(text: "${maxOutside + 2}");
    useListenable(startCtrl);
    final corner = useState(LedCorner.topLeft);
    final order = useState(LedOrder.rows);

    // Ô nhập là 1-based
    final start = (int.tryParse(startCtrl.text.trim()) ?? 0) - 1;
    final valid = start >= 0 && start + selection.length <= storage.ledCount;
    final conflicts = valid
        ? ref
              .read(storageRepositoryProvider)
              .ledConflicts(storage.id, ids, start, selection.length)
        : <StorageTray>[];
    final sorted = sortTraysForLed(
      [
        for (final t in selection)
          (id: t.id, x: t.xMm, y: t.yMm, w: t.frontWidthMm, h: t.frontHeightMm),
      ],
      order.value,
      corner: corner.value,
    );

    Future<void> apply() async {
      final repo = ref.read(storageRepositoryProvider);
      final undo = ref.read(storageUndoProvider.notifier);
      final before = repo.ledSnapshot(storage.id);
      final ok = await repo
          .numberLeds(
            storage.id,
            ids.toList(),
            start,
            order.value,
            corner: corner.value,
          )
          .then((_) => true)
          .withToast(context);
      if (ok != true) return;
      undo.push(
        storage.id,
        "Đánh số LED ${selection.length} khay",
        () => repo.restoreLeds(before),
      );
      if (context.mounted) Navigator.pop(context);
    }

    return AppAlertDialog(
      title: "Đánh số LED cho ${selection.length} khay",
      size: AlertDialogSize.big,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: startCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "LED bắt đầu (1–${storage.ledCount})",
                errorText: valid
                    ? null
                    : "Cần LED ${start + 1}–${start + selection.length}, "
                          "kho chỉ có ${storage.ledCount}",
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<LedCorner>(
                    initialValue: corner.value,
                    decoration: const InputDecoration(labelText: "Góc bắt đầu"),
                    items: [
                      for (final c in LedCorner.values)
                        DropdownMenuItem(value: c, child: Text(c.label)),
                    ],
                    onChanged: (v) => corner.value = v ?? corner.value,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<LedOrder>(
                    initialValue: order.value,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Hướng"),
                    items: [
                      for (final o in LedOrder.values)
                        DropdownMenuItem(value: o, child: Text(o.label)),
                    ],
                    onChanged: (v) => order.value = v ?? order.value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: CustomPaint(
                  painter: _PreviewPainter(
                    trays: selection,
                    order: sorted,
                    start: start < 0 ? 0 : start,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            if (conflicts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  "Các khay này đang giữ LED trong dải và sẽ bị bỏ LED: "
                  "${conflicts.map((t) => "${t.label} (LED ${t.ledIndex + 1})").join(", ")}",
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Áp dụng",
          size: ButtonSize.small,
          isDisabled: !valid,
          onPressed: apply,
        ),
      ],
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final List<StorageTray> trays;
  final List<int> order;
  final int start;

  _PreviewPainter({
    required this.trays,
    required this.order,
    required this.start,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trays.isEmpty) return;
    var minX = double.infinity, minY = double.infinity;
    var maxX = 0.0, maxY = 0.0;
    for (final t in trays) {
      if (t.xMm < minX) minX = t.xMm;
      if (t.yMm < minY) minY = t.yMm;
      if (t.xMm + t.frontWidthMm > maxX) maxX = t.xMm + t.frontWidthMm;
      if (t.yMm + t.frontHeightMm > maxY) maxY = t.yMm + t.frontHeightMm;
    }
    const pad = 12.0;
    final w = (maxX - minX).clamp(1, double.infinity);
    final h = (maxY - minY).clamp(1, double.infinity);
    final scale = ((size.width - pad * 2) / w) < ((size.height - pad * 2) / h)
        ? (size.width - pad * 2) / w
        : (size.height - pad * 2) / h;
    Rect rectOf(StorageTray t) => Rect.fromLTWH(
      pad + (t.xMm - minX) * scale,
      pad + (t.yMm - minY) * scale,
      t.frontWidthMm * scale,
      t.frontHeightMm * scale,
    );
    final byId = {for (final t in trays) t.id: t};
    final fill = Paint()..color = AppColors.primarySoft;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.primary;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.warning;
    for (final t in trays) {
      final r = rectOf(t).deflate(1);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, border);
    }
    for (var i = 0; i + 1 < order.length; i++) {
      canvas.drawLine(
        rectOf(byId[order[i]]!).center,
        rectOf(byId[order[i + 1]]!).center,
        line,
      );
    }
    for (var i = 0; i < order.length; i++) {
      final c = rectOf(byId[order[i]]!).center;
      final tp = TextPainter(
        text: TextSpan(
          text: "${start + i + 1}",
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawRect(
        Rect.fromCenter(center: c, width: tp.width + 6, height: tp.height + 2),
        Paint()..color = AppColors.surface,
      );
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.order != order || old.start != start || old.trays != trays;
}
