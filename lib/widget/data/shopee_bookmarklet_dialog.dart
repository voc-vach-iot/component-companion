import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/util/bookmarklet.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hướng dẫn cài bookmarklet lấy linh kiện từ đơn mua Shopee.
class ShopeeBookmarkletDialog extends StatelessWidget {
  const ShopeeBookmarkletDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
    context: context,
    builder: (_) => const ShopeeBookmarkletDialog(),
  );

  static const _steps = [
    "Bấm \"Sao chép bookmarklet\" bên dưới.",
    "Trên trình duyệt: tạo bookmark mới (Ctrl+D hoặc chuột phải thanh dấu trang > Thêm trang), "
        "đặt tên VD \"Lấy linh kiện Shopee\", dán nội dung vừa sao chép vào ô URL rồi lưu.",
    "Mở shopee.vn rồi bấm bookmark ở 1 trong 3 trang: Đơn mua (lấy mọi sản phẩm đang hiện, "
        "có nút cuộn tải thêm đơn), chi tiết 1 đơn hàng (có kèm link sản phẩm), hoặc trang "
        "sản phẩm (tick chọn phân loại cần lấy rồi tự bấm từng tổ hợp để đọc giá).",
    "Sửa tên / thuộc tính / số cái mỗi gói nếu cần, rồi bấm \"Sao chép cho app\".",
    "Quay lại app: trang Linh kiện bấm \"Thêm từ Shopee\" (hoặc trang Dữ liệu > "
        "\"Dán từ clipboard\") để xem trước và nhập.",
  ];

  @override
  Widget build(BuildContext context) {
    Future<void> copy() async {
      final source = await rootBundle.loadString(Bookmarklet.shopeeOrdersAsset);
      await Clipboard.setData(ClipboardData(text: Bookmarklet.build(source)));
      if (context.mounted) {
        AppSnackBar.show(
          context,
          message: "Đã sao chép bookmarklet, dán vào ô URL của bookmark",
          type: SnackBarType.success,
        );
      }
    }

    return AppAlertDialog(
      title: "Lấy linh kiện từ đơn mua Shopee",
      cancelLabel: "Đóng",
      size: AlertDialogSize.big,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, step) in _steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      "${i + 1}",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(step)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            "Script chỉ đọc nội dung trang đang mở, không gửi dữ liệu đi đâu. "
            "Số cái/gói được đoán từ phân loại (VD \"Gói 100 cái\"), nên kiểm "
            "tra lại trước khi nhập. Nếu Shopee đổi giao diện mà không đọc "
            "được, hãy lưu HTML trang đó gửi lại để cập nhật script.",
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        AppButton(
          label: "Sao chép bookmarklet",
          icon: Icons.bookmark_add_outlined,
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          onPressed: copy,
        ),
      ],
    );
  }
}
