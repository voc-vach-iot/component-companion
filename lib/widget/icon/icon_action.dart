import 'package:component_companion/data/icon_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/service/file_service.dart';
import 'package:component_companion/util/icon_csv.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/icon/icon_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class IconAction {
  /// Đọc repository từ [context] (dùng được trong widget không phải Consumer,
  /// VD ô nhập SVG dùng chung).
  static IconRepository _repo(BuildContext context) =>
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(iconRepositoryProvider);

  static void showAdd(
    BuildContext context, {
    String initialSvg = "",
    String initialName = "",
    String initialPack = IconRepository.userPack,
  }) {
    final repo = _repo(context);
    showDialog(
      context: context,
      builder: (dialogContext) => IconDialog(
        initialSvg: initialSvg,
        initialName: initialName,
        initialPack: initialPack,
        onSave: (icon) async {
          final id = await repo.save(icon).withToast(dialogContext) ?? 0;
          if (id <= 0) return false;
          if (context.mounted) {
            AppSnackBar.show(
              context,
              message: "Đã lưu '${icon.name}' vào bộ '${icon.pack}'",
              type: SnackBarType.success,
            );
          }
          return true;
        },
      ),
    );
  }

  static void showEdit(BuildContext context, IconAsset icon) {
    final repo = _repo(context);
    showDialog(
      context: context,
      builder: (dialogContext) => IconDialog(
        icon: icon,
        onDelete: () => showDelete(context, icon),
        onSave: (updated) async =>
            (await repo.save(updated).withToast(dialogContext) ?? 0) > 0,
      ),
    );
  }

  static void showDelete(BuildContext context, IconAsset icon) {
    final repo = _repo(context);
    showDialog(
      context: context,
      builder: (_) => ConfirmDeleteDialog(
        title: "Xóa icon",
        content: "Xoá icon '${icon.name}' khỏi thư viện?",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(iconIds: [icon.id]),
          delete: () => repo.delete(icon.id),
          message: "Đã xóa icon '${icon.name}'",
        ),
      ),
    );
  }

  static void showDeletePack(BuildContext context, String pack, int count) {
    final repo = _repo(context);
    showDialog(
      context: context,
      builder: (_) => ConfirmDeleteDialog(
        title: "Xóa bộ icon",
        content:
            "Xoá bộ '$pack' ($count icon)? Icon đã dùng cho danh mục / loại / "
            "linh kiện vẫn giữ nguyên.",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) =>
              transfer.snapshot(iconIds: repo.idsOfPack(pack)),
          delete: () async => await repo.deletePack(pack) > 0,
          message: "Đã xóa bộ '$pack'",
        ),
      ),
    );
  }

  /// Nhập 1 hay nhiều file CSV, mỗi file là 1 bộ (theo tên file nếu CSV
  /// không có cột "pack").
  static Future<void> importCsv(BuildContext context) async {
    final repo = _repo(context);
    final file = await FileService.pickText(
      dialogTitle: "Chọn file CSV bộ icon",
      extensions: const ["csv", "txt"],
    ).withToast(context);
    if (file == null || !context.mounted) return;

    final parsed = IconCsv.decode(
      file.content,
      defaultPack: p.basenameWithoutExtension(file.name),
    );
    if (parsed.icons.isEmpty) {
      AppSnackBar.show(
        context,
        message: "Không đọc được icon nào. Cần cột name + svg (xem file mẫu).",
        type: SnackBarType.error,
      );
      return;
    }
    final result = repo.import(parsed.icons);
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: [
        "Đã thêm ${result.added} icon",
        if (result.updated > 0) "cập nhật ${result.updated}",
        if (result.skipped > 0) "${result.skipped} đã có",
        if (parsed.skipped > 0) "bỏ qua ${parsed.skipped} dòng lỗi",
      ].join(", "),
      type: SnackBarType.success,
      duration: const Duration(seconds: 4),
    );
  }

  /// Xuất [icons] ra CSV (cùng định dạng để nhập lại / chia sẻ).
  static Future<void> exportCsv(
    BuildContext context,
    List<IconAsset> icons, {
    String name = "icons",
  }) async {
    final path = await FileService.saveText(
      dialogTitle: "Lưu bộ icon",
      fileName: "${FileService.timestamped(name)}.csv",
      content: IconCsv.encode(icons),
      extensions: const ["csv"],
      withBom: true,
    ).withToast(context);
    if (path != null && context.mounted) {
      AppSnackBar.show(
        context,
        message: "Đã lưu: $path",
        type: SnackBarType.success,
      );
    }
  }

  static Future<void> saveTemplate(BuildContext context) async {
    const sample =
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" '
        'height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
        'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
        '<path d="M2 12h6"/><path d="M16 12h6"/><path d="M8 6v12"/>'
        '<path d="M16 6v12"/></svg>';
    await exportCsv(context, [
      IconAsset(
        name: "Tụ không phân cực",
        svg: sample,
        pack: "Bộ của tôi",
        keywords: ["tụ", "capacitor"],
      ),
    ], name: "mau-bo-icon");
  }
}
