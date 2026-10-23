import 'package:component_companion/data/component_option_repository.dart';
import 'package:component_companion/data/shop_repository.dart';
import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/widget/component/component_action.dart';
import 'package:component_companion/notifier/component_option_notifier.dart';
import 'package:component_companion/notifier/shop_notifier.dart';
import 'package:component_companion/widget/component/component_option_dialog.dart';
import 'package:component_companion/widget/component/price_history_dialog.dart';
import 'package:component_companion/widget/component/variant_action.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ComponentOptionAction {
  static ComponentOptionDialog _dialog(
    BuildContext dialogContext,
    WidgetRef ref,
    Component component, {
    ComponentOption? option,
    ComponentOption? prefill,
    Set<int> initialVariantIds = const {},
    required Future<bool> Function(ComponentOption option) onSave,
  }) => ComponentOptionDialog(
    component: component,
    option: option,
    prefill: prefill,
    initialVariantIds: initialVariantIds,
    shops: ref.read(shopRepositoryProvider).all(),
    onCreateShop: (name) async {
      final shop = Shop(name: name);
      final id =
          await ref
              .read(shopProvider.notifier)
              .addShop(shop)
              .withToast(dialogContext) ??
          0;
      return id > 0 ? (shop..id = id) : null;
    },
    onCreateVariant: component.hasVariants
        ? () async {
            final id = await VariantAction.showAdd(
              dialogContext,
              ref,
              component,
            );
            return id == null
                ? null
                : ref.read(variantRepositoryProvider).get(id);
          }
        : null,
    // Combo: chọn biến thể của mọi linh kiện, hoặc tạo linh kiện mới tại chỗ
    allVariants: allVariants,
    onCreateComponent: (name) => createPartComponent(dialogContext, ref, name),
    onSave: onSave,
  );

  /// Mọi biến thể (của mọi linh kiện) để chọn làm thành phần combo, theo tên.
  static List<ComponentVariant> allVariants() {
    final all = ObjectboxService.instance.get<ComponentVariant>().getAll()
      ..removeWhere((v) => v.component.target == null);
    String label(ComponentVariant v) {
      final c = v.component.target!;
      return v.isDefault ? c.name : "${c.name} ${v.labelFor(c.attributes)}";
    }

    return all..sort((a, b) => label(a).compareTo(label(b)));
  }

  /// Tạo nhanh linh kiện làm thành phần combo, trả về biến thể đầu tiên.
  static Future<ComponentVariant?> createPartComponent(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final id = await ComponentAction.showAdd(context, ref, initialName: name);
    if (id == null) return null;
    final created = ObjectboxService.instance.get<Component>().get(id);
    final variant = created?.sortedVariants.firstOrNull;
    if (variant == null && context.mounted) {
      AppSnackBar.show(
        context,
        message: "Linh kiện mới chưa có biến thể — tạo biến thể rồi chọn lại",
        type: SnackBarType.info,
      );
    }
    return variant;
  }

  /// Thêm tuỳ chọn. [prefill] = nhân bản từ tuỳ chọn khác (chưa lưu gì cho tới
  /// khi bấm Thêm, nên tuỳ chọn mới không kế thừa lịch sử giá).
  /// Trả về id tuỳ chọn mới (null nếu huỷ / lỗi).
  static Future<int?> showAdd(
    BuildContext context,
    WidgetRef ref,
    Component component, {
    ComponentOption? prefill,
    Set<int> initialVariantIds = const {},
    ValueChanged<int>? onSuccess,
  }) async {
    int? createdId;
    await showDialog(
      context: context,
      builder: (dialogContext) => _dialog(
        dialogContext,
        ref,
        component,
        prefill: prefill,
        initialVariantIds: initialVariantIds,
        onSave: (newOption) async {
          final id =
              await ref
                  .read(componentOptionProvider.notifier)
                  .addComponentOption(newOption)
                  .withToast(dialogContext) ??
              0;
          if (id <= 0) return false;
          if (context.mounted) {
            AppSnackBar.show(
              context,
              message: "Thêm tùy chọn thành công",
              type: SnackBarType.success,
            );
          }
          createdId = id;
          onSuccess?.call(id);
          return true;
        },
      ),
    );
    return createdId;
  }

  static void clone(
    BuildContext context,
    WidgetRef ref,
    Component component,
    ComponentOption option, {
    ValueChanged<int>? onSuccess,
  }) => showAdd(context, ref, component, prefill: option, onSuccess: onSuccess);

  static void showEdit(
    BuildContext context,
    WidgetRef ref,
    Component component,
    ComponentOption option,
  ) {
    // Sửa trên bản đọc mới để huỷ / lỗi không làm bẩn dữ liệu đang hiển thị
    final fresh = ref.read(componentOptionRepositoryProvider).get(option.id);
    if (fresh == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) => _dialog(
        dialogContext,
        ref,
        component,
        option: fresh,
        onSave: (updated) async {
          final id =
              await ref
                  .read(componentOptionProvider.notifier)
                  .updateComponentOption(updated)
                  .withToast(dialogContext) ??
              0;
          if (id <= 0) return false;
          if (context.mounted) {
            AppSnackBar.show(
              context,
              message: "Cập nhật tùy chọn thành công",
              type: SnackBarType.success,
            );
          }
          return true;
        },
      ),
    );
  }

  // Xác nhận giá vẫn đúng (đã kiểm tra lại trên shop)
  static Future<void> confirmPrice(
    BuildContext context,
    WidgetRef ref,
    ComponentOption option,
  ) async {
    final id =
        await ref
            .read(componentOptionProvider.notifier)
            .confirmPrice(option.id)
            .withToast(context) ??
        0;
    if (context.mounted && id > 0) {
      AppSnackBar.show(
        context,
        message: "Đã ghi nhận giá hôm nay của '${option.displayName}'",
        type: SnackBarType.success,
      );
    }
  }

  static void showHistory(BuildContext context, ComponentOption option) {
    showDialog(
      context: context,
      builder: (context) => PriceHistoryDialog(option: option),
    );
  }

  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    ComponentOption option,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa tùy chọn",
        content: "Bạn có chắc muốn xóa tùy chọn '${option.displayName}' không?",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(optionIds: [option.id]),
          delete: () => ref
              .read(componentOptionProvider.notifier)
              .deleteComponentOption(option.id),
          message: "Đã xóa tùy chọn '${option.displayName}'",
        ),
      ),
    );
  }
}
