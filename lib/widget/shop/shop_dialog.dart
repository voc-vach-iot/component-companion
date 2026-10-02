import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Thêm / sửa shop. Đổi tên ở đây là mọi tuỳ chọn mua của shop đổi theo.
class ShopDialog extends HookWidget {
  final Shop? shop;

  /// Trả về true nếu lưu thành công (khi đó dialog tự đóng).
  final Future<bool> Function(Shop shop) onSave;

  const ShopDialog({super.key, this.shop, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final nameCtrl = useTextEditingController(text: shop?.name ?? "");
    final linkCtrl = useTextEditingController(text: shop?.link ?? "");
    final noteCtrl = useTextEditingController(text: shop?.note ?? "");
    final canSave = useValueListenable(nameCtrl).text.trim().isNotEmpty;
    final saving = useState(false);

    Future<void> save() async {
      if (!canSave || saving.value) return;
      saving.value = true;
      final next = Shop(
        id: shop?.id ?? 0,
        name: nameCtrl.text.trim(),
        link: linkCtrl.text.trim(),
        note: noteCtrl.text.trim(),
      );
      final ok = await onSave(next);
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    return AppAlertDialog(
      title: shop == null ? "Thêm shop" : "Sửa shop",
      size: AlertDialogSize.small,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: "Tên shop",
              controller: nameCtrl,
              hintText: "VD: Linh kiện ABC (Shopee)",
              autofocus: true,
            ),
            const SizedBox(height: 10),
            AppTextField(
              label: "Link shop",
              controller: linkCtrl,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            AppTextField(label: "Ghi chú", controller: noteCtrl, maxLines: 3),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: shop == null ? "Thêm mới" : "Lưu thay đổi",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: !canSave || saving.value,
          onPressed: save,
        ),
      ],
    );
  }
}
