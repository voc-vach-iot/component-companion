import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/notifier/storage_undo_notifier.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Chèn / dời số LED: mọi khay có LED từ số X trở đi cộng thêm N.
Future<void> showLedShiftDialog(
  BuildContext context,
  WidgetRef ref,
  Storage storage,
) => showDialog(
  context: context,
  builder: (_) => _LedShiftDialog(storage: storage),
);

class _LedShiftDialog extends HookConsumerWidget {
  final Storage storage;

  const _LedShiftDialog({required this.storage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromCtrl = useTextEditingController(text: "1");
    final deltaCtrl = useTextEditingController(text: "1");
    useListenable(fromCtrl);
    useListenable(deltaCtrl);
    final from = int.tryParse(fromCtrl.text.trim());
    final delta = int.tryParse(deltaCtrl.text.trim());
    final valid = from != null && from >= 1 && delta != null && delta != 0;

    Future<void> apply() async {
      final repo = ref.read(storageRepositoryProvider);
      final undo = ref.read(storageUndoProvider.notifier);
      final before = repo.ledSnapshot(storage.id);
      final ok = await repo
          .shiftLeds(storage.id, from! - 1, delta!)
          .then((_) => true)
          .withToast(context);
      if (ok != true) return;
      undo.push(
        storage.id,
        "Dời số LED từ $from ${delta > 0 ? "+" : ""}$delta",
        () => repo.restoreLeds(before),
      );
      if (context.mounted) Navigator.pop(context);
    }

    return AppAlertDialog(
      title: "Chèn / dời số LED",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: fromCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Từ LED số"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: deltaCtrl,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(labelText: "Dời bao nhiêu"),
          ),
          const SizedBox(height: 10),
          const Text(
            "Mọi khay có LED từ số này trở đi được cộng thêm số vừa nhập. "
            "Số dương = chèn chỗ trống cho cụm khay mới; số âm = dồn lại "
            "khoảng trống.",
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
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
