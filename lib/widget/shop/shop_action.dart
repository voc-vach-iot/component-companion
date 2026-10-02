import 'package:component_companion/data/shop_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/notifier/shop_notifier.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:component_companion/widget/shop/shop_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ShopAction {
  /// Thêm shop. Trả về shop đã tạo (hoặc null nếu huỷ / lỗi).
  static Future<Shop?> showAdd(
    BuildContext context,
    WidgetRef ref, {
    String initialName = "",
  }) async {
    Shop? created;
    await showDialog(
      context: context,
      builder: (dialogContext) => ShopDialog(
        shop: initialName.isEmpty ? null : Shop(name: initialName),
        onSave: (shop) async {
          shop.id = 0;
          final id =
              await ref
                  .read(shopProvider.notifier)
                  .addShop(shop)
                  .withToast(dialogContext) ??
              0;
          if (id <= 0) return false;
          created = shop..id = id;
          if (context.mounted) {
            AppSnackBar.show(
              context,
              message: "Đã thêm shop '${shop.name}'",
              type: SnackBarType.success,
            );
          }
          return true;
        },
      ),
    );
    return created;
  }

  static void showEdit(BuildContext context, WidgetRef ref, Shop shop) {
    showDialog(
      context: context,
      builder: (dialogContext) => ShopDialog(
        shop: shop,
        onSave: (next) async {
          final id =
              await ref
                  .read(shopProvider.notifier)
                  .updateShop(next)
                  .withToast(dialogContext) ??
              0;
          if (id <= 0) return false;
          if (context.mounted) {
            AppSnackBar.show(
              context,
              message: "Đã cập nhật shop '${next.name}'",
              type: SnackBarType.success,
            );
          }
          return true;
        },
      ),
    );
  }

  /// Gộp [shop] vào 1 shop khác (VD 2 tên của cùng 1 shop).
  static void showMerge(BuildContext context, WidgetRef ref, Shop shop) {
    final others = ref
        .read(shopRepositoryProvider)
        .all()
        .where((s) => s.id != shop.id)
        .toList();
    if (others.isEmpty) {
      AppSnackBar.show(
        context,
        message: "Chưa có shop nào khác để gộp vào",
        type: SnackBarType.info,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => _MergeDialog(
        shop: shop,
        others: others,
        onMerge: (target) async {
          final moved = await ref
              .read(shopProvider.notifier)
              .mergeShop(shop.id, target.id)
              .withToast(dialogContext);
          if (moved == null) return;
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          if (context.mounted) {
            AppSnackBar.show(
              context,
              message:
                  "Đã gộp '${shop.name}' vào '${target.name}' ($moved tuỳ chọn mua)",
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }

  static void showDelete(BuildContext context, WidgetRef ref, Shop shop) {
    final count = shop.options.length;
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa shop",
        content: count == 0
            ? "Bạn có chắc muốn xóa shop '${shop.name}' không?"
            : "Shop '${shop.name}' đang có $count tuỳ chọn mua. Xoá shop thì "
                  "các tuỳ chọn này vẫn còn nhưng thành \"chưa ghi shop\". "
                  "Nếu shop chỉ đổi tên, hãy dùng Sửa hoặc Gộp vào.",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(shopIds: [shop.id]),
          delete: () => ref.read(shopProvider.notifier).deleteShop(shop.id),
          message: "Đã xóa shop '${shop.name}'",
        ),
      ),
    );
  }
}

class _MergeDialog extends HookWidget {
  final Shop shop;
  final List<Shop> others;
  final Future<void> Function(Shop target) onMerge;

  const _MergeDialog({
    required this.shop,
    required this.others,
    required this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    final target = useState<Shop?>(null);
    return AppAlertDialog(
      title: "Gộp shop",
      size: AlertDialogSize.small,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Mọi tuỳ chọn mua của '${shop.name}' sẽ chuyển sang shop được chọn, "
            "sau đó '${shop.name}' bị xoá.",
          ),
          const SizedBox(height: 12),
          AppSearchSelect<Shop>(
            label: "Gộp vào",
            items: others,
            value: target.value,
            labelOf: (s) => s.name,
            subtitleOf: (s) => "${s.options.length} tuỳ chọn mua",
            onChanged: (s) => target.value = s,
          ),
        ],
      ),
      actions: [
        AppButton(
          label: "Gộp",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: target.value == null,
          onPressed: () => onMerge(target.value!),
        ),
      ],
    );
  }
}
