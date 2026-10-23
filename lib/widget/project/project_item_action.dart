import 'package:component_companion/data/project_item_repository.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/notifier/component_notifier.dart';
import 'package:component_companion/notifier/project_item_notifier.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/dialog/confirm_delete_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:component_companion/widget/notification/undo_delete.dart';
import 'package:component_companion/util/project_duplicates.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/project/project_duplicate_dialog.dart';
import 'package:component_companion/widget/project/project_item_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectItemAction {
  static void showAdd(
    BuildContext context,
    WidgetRef ref, {
    Project? project,
    ProjectOption? projectOption,
    VoidCallback? onSuccess,
  }) {
    // Dialog thêm đóng ngay khi lưu => hỏi trùng / báo kết quả trên trang
    showDialog(
      context: context,
      builder: (_) => ComponentLoader(
        // ComponentLoader lấy từ watchAllComponentsProvider
        builder: (availableComponents) => ProjectItemDialog(
          project: project,
          projectOption: projectOption,
          availableComponents: availableComponents,
          onSaveCombo: (items) async {
            if (await addItems(context, ref, items) case final r?) {
              if (r.added + r.merged > 0) onSuccess?.call();
            }
          },
          onSave: (newItem) async {
            if (await addItems(context, ref, [newItem]) case final r?) {
              if (r.added + r.merged > 0) onSuccess?.call();
            }
          },
        ),
      ),
    );
  }

  /// Thêm [items] vào dự án; linh kiện đã có (cùng biến thể) => hỏi gộp vào
  /// dòng có sẵn hay thêm dòng mới. null = huỷ / lỗi.
  static Future<({int added, int merged})?> addItems(
    BuildContext context,
    WidgetRef ref,
    List<ProjectItem> items,
  ) async {
    if (items.isEmpty) return (added: 0, merged: 0);
    final repo = ref.read(projectItemRepositoryProvider);
    final projectId = repo.projectIdOf(items.first);
    final existing = projectId == 0
        ? const <ProjectItem>[]
        : repo.allOfProject(projectId);
    final matches = [
      for (final item in items) ProjectDuplicates.matches(item, existing),
    ];
    var mergeInto = const <int, int>{};
    if (matches.any((m) => m.isNotEmpty)) {
      final choice = await ProjectDuplicateDialog.show(
        context,
        items: items,
        matches: matches,
      );
      if (choice == null || !context.mounted) return null;
      mergeInto = choice;
    }
    final result = await repo
        .addOrMerge(items, mergeInto: mergeInto)
        .withToast(context);
    if (result != null && context.mounted) {
      AppSnackBar.show(
        context,
        message: [
          if (result.added > 0) "Đã thêm ${result.added} linh kiện",
          if (result.merged > 0)
            "Đã gộp ${result.merged} linh kiện vào dòng có sẵn",
        ].join(" · "),
        type: SnackBarType.success,
      );
    }
    return result;
  }

  /// Gộp các dòng trùng (cùng phần + cùng biến thể) sau khi xác nhận; có
  /// hoàn tác.
  static Future<void> mergeDuplicates(
    BuildContext context,
    WidgetRef ref,
    List<List<ProjectItem>> groups,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: "Gộp linh kiện trùng",
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Mỗi nhóm gộp thành 1 dòng (cộng số lượng, giữ nơi mua của "
                  "dòng thêm trước):",
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "• ${g.first.variant.target?.fullLabel ?? "Linh kiện"} "
                      "(${ProjectDuplicates.placeOf(g.first)}): "
                      "${g.map((i) => i.quantity).join(" + ")} = "
                      "${g.fold(0, (s, i) => s + i.quantity)} cái",
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: "Gộp ${groups.length} nhóm",
            size: ButtonSize.small,
            variant: ButtonVariant.primary,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(projectItemRepositoryProvider);
    final undo = await repo.mergeDuplicates(groups).withToast(context);
    if (undo == null) return;
    AppSnackBar.showWith(
      messenger,
      message: "Đã gộp ${groups.length} nhóm linh kiện trùng",
      type: SnackBarType.success,
      duration: const Duration(seconds: 10),
      actionLabel: "Hoàn tác",
      onAction: () => repo.undoMerge(undo),
    );
  }

  static void showEdit(
    BuildContext context,
    WidgetRef ref, {
    required ProjectItem item,
  }) {
    // Dialog đóng trước khi lưu => báo kết quả bằng context của trang
    showDialog(
      context: context,
      builder: (_) => ComponentLoader(
        builder: (availableComponents) => ProjectItemDialog(
          projectItem: item,
          availableComponents: availableComponents,
          onSave: (updatedItem) async {
            final id =
                await ref
                    .read(projectItemProvider.notifier)
                    .updateProjectItem(updatedItem)
                    .withToast(context) ??
                0;

            if (context.mounted && id > 0) {
              AppSnackBar.show(
                context,
                message: "Đã cập nhật",
                type: SnackBarType.success,
              );
            }
          },
        ),
      ),
    );
  }

  /// Đổi nhanh số lượng (nút +/− trên dòng linh kiện).
  static Future<void> setQuantity(
    BuildContext context,
    WidgetRef ref,
    ProjectItem item,
    int quantity,
  ) async {
    if (quantity <= 0 || quantity == item.quantity) return;
    item.quantity = quantity;
    await ref
        .read(projectItemProvider.notifier)
        .updateProjectItem(item)
        .withToast(context);
  }

  /// Đổi linh kiện sang tuỳ chọn mua hàng khác (VD shop rẻ hơn).
  static Future<void> switchOption(
    BuildContext context,
    WidgetRef ref,
    ProjectItem item,
    ComponentOption option,
  ) async {
    item.componentOption.targetId = option.id;
    final id =
        await ref
            .read(projectItemProvider.notifier)
            .updateProjectItem(item)
            .withToast(context) ??
        0;
    if (context.mounted && id > 0) {
      AppSnackBar.show(
        context,
        message: "Đã đổi sang ${option.displayName}",
        type: SnackBarType.success,
      );
    }
  }

  static void showDelete(
    BuildContext context,
    WidgetRef ref,
    ProjectItem item,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        title: "Xóa linh kiện",
        content: "Bạn có chắc chắn muốn xóa linh kiện này khỏi dự án không?",
        onConfirm: () => UndoDelete.run(
          context,
          snapshot: (transfer) => transfer.snapshot(projectItemIds: [item.id]),
          delete: () =>
              ref.read(projectItemProvider.notifier).deleteProjectItem(item.id),
          message: "Đã xóa linh kiện khỏi dự án",
        ),
      ),
    );
  }
}

// Helper widget để load dữ liệu trước khi hiện Dialog
class ComponentLoader extends ConsumerWidget {
  final Widget Function(List<Component> components) builder;

  const ComponentLoader({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final componentsAsync = ref.watch(watchAllComponentsProvider());

    return componentsAsync.when(
      loading: () => const AppLoadingView(),
      error: (err, _) => AppErrorView(message: "Lỗi khi tải linh kiện: $err"),
      data: (components) {
        // Danh sách rỗng vẫn mở dialog: có nút tạo linh kiện ngay tại chỗ
        return builder(components);
      },
    );
  }
}
