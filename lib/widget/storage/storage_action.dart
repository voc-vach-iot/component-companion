import 'package:component_companion/data/power_supply_repository.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/data/tray_type_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/notifier/storage_undo_notifier.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/storage/compartment_target_dialog.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:component_companion/widget/storage/power_supply_dialog.dart';
import 'package:component_companion/widget/storage/storage_dialog.dart';
import 'package:component_companion/widget/storage/tray_type_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Thêm / sửa / xoá kho, loại khay, nguồn, khay.
class StorageAction {
  /// Lưu bằng [save]; lỗi thì hiện toast trên [dialogContext].
  static Future<bool> _save(
    BuildContext context,
    BuildContext dialogContext,
    Future<int> Function() save,
    String message,
  ) async {
    final id = await save().withToast(dialogContext) ?? 0;
    if (id <= 0) return false;
    if (context.mounted) {
      AppSnackBar.show(context, message: message, type: SnackBarType.success);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // LOẠI KHAY
  // ---------------------------------------------------------------------------

  static void showTrayType(
    BuildContext context,
    WidgetRef ref, [
    TrayType? type,
  ]) {
    final repo = ref.read(trayTypeRepositoryProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => TrayTypeDialog(
        type: type,
        onSave: (next) => _save(
          context,
          dialogContext,
          () => type == null ? repo.add(next) : repo.update(next),
          type == null
              ? "Đã thêm loại khay '${next.name}'"
              : "Đã cập nhật loại khay '${next.name}'",
        ),
      ),
    );
  }

  static void deleteTrayType(
    BuildContext context,
    WidgetRef ref,
    TrayType type,
  ) {
    showDialog(
      context: context,
      builder: (_) => ConfirmDeleteDialog(
        title: "Xoá loại khay",
        content: "Xoá loại khay '${type.name}'?",
        onConfirm: () async {
          final ok = await ref
              .read(trayTypeRepositoryProvider)
              .delete(type.id)
              .withToast(context);
          if (ok == true && context.mounted) {
            AppSnackBar.show(
              context,
              message: "Đã xoá loại khay '${type.name}'",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NGUỒN
  // ---------------------------------------------------------------------------

  static void showSupply(
    BuildContext context,
    WidgetRef ref, [
    PowerSupply? supply,
  ]) {
    final repo = ref.read(powerSupplyRepositoryProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => PowerSupplyDialog(
        supply: supply,
        onSave: (next) => _save(
          context,
          dialogContext,
          () => supply == null ? repo.add(next) : repo.update(next),
          supply == null
              ? "Đã thêm nguồn '${next.name}'"
              : "Đã cập nhật nguồn '${next.name}'",
        ),
      ),
    );
  }

  static void deleteSupply(
    BuildContext context,
    WidgetRef ref,
    PowerSupply supply,
  ) {
    showDialog(
      context: context,
      builder: (_) => ConfirmDeleteDialog(
        title: "Xoá nguồn",
        content:
            "Xoá nguồn '${supply.name}'? Kho đang dùng nguồn này sẽ thành "
            "\"chưa chọn nguồn\" (tạm tính 1A).",
        onConfirm: () async {
          final ok = await ref
              .read(powerSupplyRepositoryProvider)
              .delete(supply.id)
              .withToast(context);
          if (ok == true && context.mounted) {
            AppSnackBar.show(
              context,
              message: "Đã xoá nguồn '${supply.name}'",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KHO
  // ---------------------------------------------------------------------------

  /// Thêm / sửa kho. Trả về id kho (null nếu huỷ).
  static Future<int?> showStorage(
    BuildContext context,
    WidgetRef ref, [
    Storage? storage,
  ]) async {
    final repo = ref.read(storageRepositoryProvider);
    final supplies = ref.read(powerSupplyRepositoryProvider).all();
    int? savedId;
    await showDialog(
      context: context,
      builder: (dialogContext) => StorageDialog(
        storage: storage,
        supplies: supplies,
        onSave: (next) => _save(context, dialogContext, () async {
          final id = storage == null
              ? await repo.add(next)
              : await repo.update(next);
          savedId = id;
          return id;
        }, storage == null ? "Đã thêm kho '${next.name}'" : "Đã lưu kho"),
      ),
    );
    return savedId;
  }

  static void deleteStorage(
    BuildContext context,
    WidgetRef ref,
    Storage storage,
  ) {
    final trays = storage.trays.length;
    showDialog(
      context: context,
      builder: (_) => ConfirmDeleteDialog(
        title: "Xoá kho",
        content: trays == 0
            ? "Xoá kho '${storage.name}'?"
            : "Xoá kho '${storage.name}' cùng $trays khay? Linh kiện cất trong "
                  "kho sẽ thành \"chưa có chỗ\".",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(storageIds: [storage.id]),
          delete: () => ref.read(storageRepositoryProvider).delete(storage.id),
          message: "Đã xoá kho '${storage.name}'",
        ),
      ),
    );
  }

  /// Xoá khay (có hoàn tác). Khay đang có linh kiện thì hỏi trước.
  static Future<void> deleteTrays(
    BuildContext context,
    WidgetRef ref,
    List<int> trayIds,
  ) async {
    if (trayIds.isEmpty) return;
    final repo = ref.read(storageRepositoryProvider);
    final used = trayIds.where((id) => repo.contentsOf(id).isNotEmpty).length;
    Future<void> run() => UndoDelete.run(
      context,
      snapshot: (transfer) => transfer.snapshot(storageTrayIds: trayIds),
      delete: () async => await repo.deleteTrays(trayIds) > 0,
      message: "Đã xoá ${trayIds.length} khay",
    );
    if (used == 0) return run();
    await showDialog(
      context: context,
      builder: (_) => ConfirmDeleteDialog(
        title: "Xoá khay",
        content:
            "$used khay đang có linh kiện. Xoá thì các linh kiện đó thành "
            "\"chưa có chỗ\".",
        onConfirm: run,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KHAY: ĐỔI TÊN, CHUYỂN NGĂN
  // ---------------------------------------------------------------------------

  /// Đổi tên khay bằng hộp nhập nhanh.
  static Future<void> renameTray(
    BuildContext context,
    WidgetRef ref,
    StorageTray tray,
  ) async {
    final ctrl = TextEditingController(text: tray.label);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: "Đổi tên khay",
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Tên khay"),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          AppButton(
            label: "Lưu",
            size: ButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext, ctrl.text),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim() == tray.label || !context.mounted) return;
    final repo = ref.read(storageRepositoryProvider);
    final old = tray.label;
    final next = repo.tray(tray.id);
    if (next == null) return;
    next.label = name;
    final ok = await repo.updateTray(next).then((_) => true).withToast(context);
    if (ok == true) {
      ref.read(storageUndoProvider.notifier).push(
        next.storage.targetId,
        "Đổi tên khay $old",
        () async {
          final t = repo.tray(tray.id);
          if (t == null) return;
          t.label = old;
          await repo.updateTray(t);
        },
      );
    }
  }

  /// Chuyển đồ ở ngăn [fromIndex] của [from] sang ngăn [toIndex] của [to].
  /// Ngăn đích có đồ thì hỏi gộp hay đổi chỗ.
  static Future<void> moveCompartment(
    BuildContext context,
    WidgetRef ref,
    StorageTray from,
    int fromIndex,
    StorageTray to,
    int toIndex,
  ) async {
    final repo = ref.read(storageRepositoryProvider);
    if (from.id == to.id && fromIndex == toIndex) return;
    final targetBusy = repo.contentsOf(to.id)[toIndex]?.isNotEmpty ?? false;
    var swap = false;
    if (targetBusy) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: "Ngăn đích đã có linh kiện",
          content: Text(
            "${to.label} / ngăn ${toIndex + 1} đang có linh kiện. Gộp đồ của "
            "${from.label} / ngăn ${fromIndex + 1} vào đó, hay đổi chỗ 2 ngăn?",
          ),
          cancelLabel: "Huỷ",
          actions: [
            AppButton(
              label: "Đổi chỗ 2 ngăn",
              variant: ButtonVariant.secondary,
              size: ButtonSize.small,
              onPressed: () => Navigator.pop(dialogContext, "swap"),
            ),
            AppButton(
              label: "Gộp vào ngăn đích",
              size: ButtonSize.small,
              onPressed: () => Navigator.pop(dialogContext, "merge"),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      swap = choice == "swap";
    }
    final before = repo.placementsOf([from.id, to.id]);
    final ok = await repo
        .moveCompartment(from.id, fromIndex, to.id, toIndex, swap: swap)
        .then((_) => true)
        .withToast(context);
    if (ok != true) return;
    ref
        .read(storageUndoProvider.notifier)
        .push(
          from.storage.targetId,
          "Chuyển ngăn ${from.label}/${fromIndex + 1} → ${to.label}/${toIndex + 1}",
          () => repo.restorePlacements(before),
        );
    if (context.mounted) {
      AppSnackBar.show(
        context,
        message: swap
            ? "Đã đổi chỗ 2 ngăn"
            : "Đã chuyển đồ sang ${to.label} / ngăn ${toIndex + 1}",
        type: SnackBarType.success,
      );
    }
  }

  /// Chọn khay + ngăn đích rồi chuyển.
  static Future<void> pickAndMoveCompartment(
    BuildContext context,
    WidgetRef ref,
    StorageTray from,
    int fromIndex,
  ) async {
    final target = await showCompartmentTargetDialog(context, from, fromIndex);
    if (target == null || !context.mounted) return;
    await moveCompartment(
      context,
      ref,
      from,
      fromIndex,
      target.tray,
      target.index,
    );
  }
}
