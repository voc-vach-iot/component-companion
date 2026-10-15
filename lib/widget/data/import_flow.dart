import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/widget/data/import_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';

/// Đọc dữ liệu (file / clipboard) => màn xem trước => nhập, kèm snackbar có
/// nút "Hoàn tác". Dùng ở trang Dữ liệu và trang Linh kiện.
class ImportFlow {
  ImportFlow._();

  /// Thử đọc [content]; lỗi định dạng => null (không báo lỗi).
  static List<ImportRow>? tryParse(String content) {
    try {
      final rows = ImportService.parse(content);
      return rows.isEmpty ? null : rows;
    } on AppException {
      return null;
    }
  }

  /// Trả về kết quả nhập, null nếu lỗi / huỷ / đã hoàn tác ngay.
  /// [onUndo] được gọi sau khi hoàn tác.
  static Future<ImportResult?> run(
    BuildContext context, {
    required String name,
    required String content,
    VoidCallback? onUndo,
  }) async {
    final service = ImportService();
    final List<ImportPlan> plans;
    try {
      plans = service.plan(ImportService.parse(content));
    } on AppException catch (e) {
      if (context.mounted) {
        AppSnackBar.show(context, message: e.message, type: SnackBarType.error);
      }
      return null;
    }
    if (!context.mounted) return null;

    final db = ObjectboxService.instance;
    final messenger = ScaffoldMessenger.of(context);
    ImportResult? result;
    await showDialog(
      context: context,
      builder: (_) => ImportDialog(
        fileName: name,
        plans: plans,
        categories: db.get<Category>().getAll(),
        types: db.get<ComponentType>().getAll(),
        components: db.get<Component>().getAll()
          ..sort((a, b) => a.name.compareTo(b.name)),
        shopHints: service.shopHints,
        onImport: (plans, addToStock, renameShops) {
          try {
            result = service.apply(
              plans,
              addToStock: addToStock,
              renameShops: renameShops,
            );
          } catch (e) {
            AppSnackBar.showWith(
              messenger,
              message: "Không nhập được: $e",
              type: SnackBarType.error,
            );
            return;
          }
          final done = result!;
          AppSnackBar.showWith(
            messenger,
            message: "Đã nhập: ${done.summary}",
            type: SnackBarType.success,
            duration: const Duration(seconds: 10),
            actionLabel: "Hoàn tác",
            onAction: () {
              try {
                service.undo(done.undo);
                onUndo?.call();
                AppSnackBar.showWith(
                  messenger,
                  message: "Đã hoàn tác lần nhập",
                  type: SnackBarType.info,
                );
              } catch (e) {
                AppSnackBar.showWith(
                  messenger,
                  message: "Không thể hoàn tác: $e",
                  type: SnackBarType.error,
                );
              }
            },
          );
        },
      ),
    );
    return result;
  }
}
