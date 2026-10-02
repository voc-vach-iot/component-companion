import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/service/backup_service.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/export_service.dart';
import 'package:component_companion/service/file_service.dart';
import 'package:component_companion/service/import_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/price_insight.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/data/import_dialog.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sao lưu - khôi phục, nhập từ đơn hàng / BOM, xuất CSV.
class DataPage extends HookWidget {
  const DataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backup = useMemoized(BackupService.new);
    // Tăng để tải lại danh sách bản sao lưu
    final refresh = useState(0);
    final backups = useMemoized(backup.listLocal, [refresh.value]);

    Future<void> confirmRestore(DataSnapshot data, String source) async {
      final counts = DataTransferService.countOf(data);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: "Khôi phục dữ liệu?",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Nguồn: $source"),
              const SizedBox(height: 8),
              Text(
                "${counts["components"]} linh kiện · ${counts["options"]} tùy chọn · "
                "${counts["projects"]} dự án · ${counts["categories"]} danh mục · "
                "${counts["types"]} loại",
              ),
              const SizedBox(height: 12),
              const Text(
                "Toàn bộ dữ liệu hiện tại sẽ được THAY THẾ. Dữ liệu hiện tại được "
                "tự động sao lưu trước khi khôi phục nên bạn vẫn có thể quay lại.",
                style: TextStyle(color: AppColors.warning),
              ),
            ],
          ),
          actions: [
            AppButton(
              label: "Khôi phục",
              variant: ButtonVariant.danger,
              size: ButtonSize.small,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;

      final safety = await backup.restore(data).withToast(context);
      refresh.value++;
      if (safety != null && context.mounted) {
        AppSnackBar.show(
          context,
          message: "Đã khôi phục. Dữ liệu cũ đã lưu ở: ${safety.path}",
          type: SnackBarType.success,
          duration: const Duration(seconds: 5),
        );
      }
    }

    Future<void> startImport({String? pastedText}) async {
      final String name;
      final String content;
      if (pastedText != null) {
        name = "dữ liệu dán";
        content = pastedText;
      } else {
        final picked = await FileService.pickText(
          dialogTitle: "Chọn file đơn hàng / BOM",
          extensions: const ["csv", "json", "txt"],
        );
        if (picked == null) return;
        name = picked.name;
        content = picked.content;
      }

      final service = ImportService();
      final List<ImportPlan> plans;
      try {
        plans = service.plan(ImportService.parse(content));
      } on AppException catch (e) {
        if (context.mounted) {
          AppSnackBar.show(
            context,
            message: e.message,
            type: SnackBarType.error,
          );
        }
        return;
      }
      if (!context.mounted) return;

      final db = ObjectboxService.instance;
      await showDialog(
        context: context,
        builder: (_) => ImportDialog(
          fileName: name,
          plans: plans,
          categories: db.get<Category>().getAll(),
          types: db.get<ComponentType>().getAll(),
          onImport: (plans, addToStock) {
            final result = service.apply(plans, addToStock: addToStock);
            AppSnackBar.show(
              context,
              message:
                  "Đã nhập: ${result.created} linh kiện mới, ${result.variantsCreated} biến thể, "
                  "${result.optionsAdded} tùy chọn mua"
                  "${result.stocked > 0 ? ", cộng kho ${result.stocked} dòng" : ""}",
              type: SnackBarType.success,
              duration: const Duration(seconds: 4),
            );
          },
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "Dữ liệu".toUpperCase(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // --- SAO LƯU ---
          _Section(
            icon: Icons.backup_outlined,
            title: "Sao lưu & khôi phục",
            description:
                "Xuất toàn bộ dữ liệu (linh kiện, giá, tồn kho, dự án, ảnh) ra 1 file JSON "
                "để chuyển máy / cài lại. App tự sao lưu mỗi ngày khi mở và giữ "
                "${BackupService.keepAuto} bản gần nhất.",
            actions: [
              AppButton(
                label: "Xuất file sao lưu",
                icon: Icons.download_rounded,
                size: ButtonSize.small,
                onPressed: () async {
                  final path = await backup.exportToFile().withToast(context);
                  if (path != null && context.mounted) {
                    AppSnackBar.show(
                      context,
                      message: "Đã lưu: $path",
                      type: SnackBarType.success,
                      duration: const Duration(seconds: 4),
                    );
                  }
                },
              ),
              AppButton(
                label: "Khôi phục từ file",
                icon: Icons.upload_rounded,
                size: ButtonSize.small,
                variant: ButtonVariant.secondary,
                onPressed: () async {
                  final data = await backup.pickFile().withToast(context);
                  if (data != null) {
                    await confirmRestore(data, "file đã chọn");
                  }
                },
              ),
              AppButton(
                label: "Mở thư mục sao lưu",
                icon: Icons.folder_open_outlined,
                size: ButtonSize.small,
                variant: ButtonVariant.secondary,
                onPressed: () async {
                  await backup.backupDir.create(recursive: true);
                  await launchUrl(Uri.directory(backup.backupDir.path));
                },
              ),
            ],
            child: backups.isEmpty
                ? const Text(
                    "Chưa có bản sao lưu nào trong máy.",
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : Column(
                    children: [
                      for (final b in backups.take(15))
                        ListTile(
                          dense: true,
                          leading: Icon(
                            b.isAuto
                                ? Icons.schedule_outlined
                                : Icons.history_outlined,
                          ),
                          title: Text(b.name),
                          subtitle: Text(
                            "${PriceInsight.formatDate(b.modifiedAt)} "
                            "${b.modifiedAt.hour.toString().padLeft(2, "0")}:"
                            "${b.modifiedAt.minute.toString().padLeft(2, "0")}"
                            " · ${(b.sizeBytes / 1024).toStringAsFixed(0)} KB",
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              final data = await backup
                                  .readLocal(b)
                                  .withToast(context);
                              if (data != null) {
                                await confirmRestore(data, b.name);
                              }
                            },
                            child: const Text("Khôi phục"),
                          ),
                        ),
                    ],
                  ),
          ),

          // --- NHẬP ---
          _Section(
            icon: Icons.playlist_add_rounded,
            title: "Nhập linh kiện từ đơn hàng / BOM",
            description:
                "File CSV (có dòng tiêu đề) hoặc JSON. Tải file mẫu, mở bằng Excel / "
                "LibreOffice / Google Sheets, điền theo các cột bên dưới rồi chọn file để nhập. "
                "Danh mục và loại được nhận diện theo từ khóa; linh kiện trùng tên "
                "sẽ được thêm biến thể / tùy chọn thay vì tạo mới.",
            actions: [
              AppButton(
                label: "Tải file mẫu",
                icon: Icons.description_outlined,
                size: ButtonSize.small,
                variant: ButtonVariant.secondary,
                onPressed: () async {
                  final path = await FileService.saveText(
                    dialogTitle: "Lưu file mẫu nhập linh kiện",
                    fileName: "mau-nhap-linh-kien.csv",
                    content: ImportService.templateCsv(),
                    extensions: const ["csv"],
                    withBom: true,
                  ).withToast(context);
                  if (path != null && context.mounted) {
                    AppSnackBar.show(
                      context,
                      message: "Đã lưu file mẫu: $path",
                      type: SnackBarType.success,
                    );
                  }
                },
              ),
              AppButton(
                label: "Chọn file CSV / JSON",
                icon: Icons.file_open_outlined,
                size: ButtonSize.small,
                onPressed: startImport,
              ),
              AppButton(
                label: "Dán từ clipboard",
                icon: Icons.content_paste_rounded,
                size: ButtonSize.small,
                variant: ButtonVariant.secondary,
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  final text = data?.text ?? "";
                  if (text.trim().isEmpty) {
                    if (context.mounted) {
                      AppSnackBar.show(
                        context,
                        message: "Clipboard đang trống",
                        type: SnackBarType.warning,
                      );
                    }
                    return;
                  }
                  await startImport(pastedText: text);
                },
              ),
            ],
            child: const _TemplateHelp(),
          ),

          // --- XUẤT ---
          _Section(
            icon: Icons.table_view_outlined,
            title: "Xuất danh sách linh kiện",
            description:
                "Mỗi tùy chọn mua hàng 1 dòng: shop, giá, đơn giá, ngày kiểm tra giá, link, tồn kho.",
            actions: [
              AppButton(
                label: "Xuất CSV",
                icon: Icons.download_rounded,
                size: ButtonSize.small,
                onPressed: () => FileService.saveText(
                  dialogTitle: "Lưu danh sách linh kiện",
                  fileName: "${FileService.timestamped("linh-kien")}.csv",
                  content: ExportService().componentsCsv(),
                  extensions: const ["csv"],
                  withBom: true,
                ).withToast(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bảng giải thích các cột của file mẫu nhập linh kiện.
class _TemplateHelp extends StatelessWidget {
  const _TemplateHelp();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text(
          "Các cột của file mẫu",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        children: [
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            border: TableBorder.all(color: AppColors.border),
            children: [
              for (final (column, description) in ImportService.templateHelp)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        column,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(description),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Widget> actions;
  final Widget? child;

  const _Section({
    required this.icon,
    required this.title,
    required this.description,
    required this.actions,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textMain),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
          if (child != null) ...[const SizedBox(height: 12), child!],
        ],
      ),
    );
  }
}
