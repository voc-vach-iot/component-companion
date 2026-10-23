import 'package:component_companion/data/power_supply_repository.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/data/tray_type_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage.dart';
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
}
