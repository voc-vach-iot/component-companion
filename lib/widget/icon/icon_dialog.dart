import 'package:component_companion/data/icon_repository.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/util/icon_csv.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/svg_input.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Thêm / sửa 1 icon trong thư viện.
class IconDialog extends HookWidget {
  /// Icon đang sửa (null = thêm mới).
  final IconAsset? icon;

  /// Bộ / SVG điền sẵn khi thêm.
  final String initialPack;
  final String initialSvg;
  final String initialName;

  /// Trả về true nếu lưu thành công (khi đó dialog tự đóng).
  final Future<bool> Function(IconAsset icon) onSave;

  /// Xoá icon đang sửa (null = ẩn nút).
  final VoidCallback? onDelete;

  const IconDialog({
    super.key,
    this.icon,
    this.initialPack = IconRepository.userPack,
    this.initialSvg = "",
    this.initialName = "",
    required this.onSave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isEdit = icon != null;
    final nameCtrl = useTextEditingController(text: icon?.name ?? initialName);
    final packCtrl = useTextEditingController(text: icon?.pack ?? initialPack);
    final keywordsCtrl = useTextEditingController(
      text: icon?.keywords.join("; ") ?? "",
    );
    final svgCtrl = useTextEditingController(text: icon?.svg ?? initialSvg);
    final name = useValueListenable(nameCtrl).text.trim();
    final svg = useValueListenable(svgCtrl).text.trim();
    final saving = useState(false);
    final canSave = name.isNotEmpty && AppSvgIcon.looksLikeSvg(svg);

    Future<void> save() async {
      if (!canSave || saving.value) return;
      saving.value = true;
      final ok = await onSave(
        IconAsset(
          id: icon?.id ?? 0,
          name: name,
          pack: packCtrl.text,
          svg: svg,
          keywords: IconCsv.splitKeywords(keywordsCtrl.text),
        ),
      );
      if (!context.mounted) return;
      saving.value = false;
      if (ok) Navigator.of(context).pop();
    }

    return AppAlertDialog(
      title: isEdit ? "Sửa icon" : "Thêm icon vào thư viện",
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: "Tên icon",
                      controller: nameCtrl,
                      autofocus: !isEdit,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(label: "Bộ icon", controller: packCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppTextField(
                label: "Từ khoá tìm kiếm (cách nhau bởi dấu ;)",
                hintText: "VD: tụ; capacitor; tụ điện",
                controller: keywordsCtrl,
              ),
              const SizedBox(height: 10),
              SvgInputField(
                label: "Mã SVG",
                controller: svgCtrl,
                showLibrary: false,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (onDelete != null) ...[
          AppButton(
            label: "Xoá",
            variant: ButtonVariant.danger,
            size: ButtonSize.small,
            onPressed: () {
              Navigator.of(context).pop();
              onDelete!();
            },
          ),
          const SizedBox(width: 8),
        ],
        AppButton(
          label: isEdit ? "Lưu" : "Thêm",
          variant: ButtonVariant.primary,
          size: ButtonSize.small,
          isDisabled: !canSave || saving.value,
          onPressed: save,
        ),
      ],
    );
  }
}
