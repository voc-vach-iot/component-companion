import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/util/rename_rule.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 1 tên được đổi trong [BulkRenameDialog].
class RenameItem {
  final int id;
  final String oldName;

  /// Dòng phụ (VD tên linh kiện của tuỳ chọn mua).
  final String subtitle;

  /// Biến cho mẫu tên, VD {"n": "10", "dv": "cái"}.
  final Map<String, String> vars;

  const RenameItem({
    required this.id,
    required this.oldName,
    this.subtitle = "",
    this.vars = const {},
  });
}

/// Đổi tên hàng loạt có xem trước: tìm / thay, tiền / hậu tố hoặc theo mẫu.
/// Trả về id -> tên mới của các dòng được tick và thực sự đổi; null nếu huỷ.
class BulkRenameDialog extends HookWidget {
  final String title;
  final List<RenameItem> items;

  /// Tên đã có ngoài danh sách (tên mới không được trùng). Rỗng = cho phép trùng.
  final Set<String>? takenNames;

  /// Các biến dùng được trong mẫu (hiện làm gợi ý); rỗng = không có chế độ mẫu.
  final List<String> templateVars;
  final String templateHint;

  const BulkRenameDialog({
    super.key,
    required this.title,
    required this.items,
    this.takenNames,
    this.templateVars = const [],
    this.templateHint = "",
  });

  static Future<Map<int, String>?> show(
    BuildContext context, {
    required String title,
    required List<RenameItem> items,
    Set<String>? takenNames,
    List<String> templateVars = const [],
    String templateHint = "",
  }) => showDialog<Map<int, String>>(
    context: context,
    builder: (_) => BulkRenameDialog(
      title: title,
      items: items,
      takenNames: takenNames,
      templateVars: templateVars,
      templateHint: templateHint,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final findCtrl = useTextEditingController();
    final replaceCtrl = useTextEditingController();
    final prefixCtrl = useTextEditingController();
    final suffixCtrl = useTextEditingController();
    final templateCtrl = useTextEditingController(
      text: templateVars.isEmpty ? "" : "{old}",
    );
    final regex = useState(false);
    final caseSensitive = useState(false);
    final useTemplate = useState(false);
    final skipped = useState<Set<int>>({});
    for (final c in [
      findCtrl,
      replaceCtrl,
      prefixCtrl,
      suffixCtrl,
      templateCtrl,
    ]) {
      useListenable(c);
    }

    final rule = RenameRule(
      find: findCtrl.text,
      replace: replaceCtrl.text,
      prefix: prefixCtrl.text,
      suffix: suffixCtrl.text,
      regex: regex.value,
      caseSensitive: caseSensitive.value,
      useTemplate: useTemplate.value,
      template: templateCtrl.text,
    );
    final error = rule.validate();

    final rows = [
      for (final item in items)
        (
          item: item,
          next: error == null
              ? rule.apply(item.oldName, item.vars)
              : item.oldName,
        ),
    ];
    final changing = [
      for (final r in rows)
        if (r.next.isNotEmpty &&
            r.next != r.item.oldName &&
            !skipped.value.contains(r.item.id))
          r,
    ];

    // Tên trùng nhau trong đợt, hoặc trùng tên có sẵn ngoài đợt
    final count = <String, int>{};
    for (final r in rows) {
      final finalName = changing.any((c) => c.item.id == r.item.id)
          ? r.next
          : r.item.oldName;
      count[finalName] = (count[finalName] ?? 0) + 1;
    }
    bool clash(({RenameItem item, String next}) r) =>
        takenNames != null &&
        ((count[r.next] ?? 0) > 1 || takenNames!.contains(r.next));
    final hasClash = changing.any(clash);

    return AppAlertDialog(
      title: title,
      size: AlertDialogSize.big,
      content: SizedBox(
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (templateVars.isNotEmpty)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text("Đặt tên theo mẫu"),
                value: useTemplate.value,
                onChanged: (v) => useTemplate.value = v,
              ),
            if (useTemplate.value) ...[
              AppTextField(
                label: "Mẫu tên",
                controller: templateCtrl,
                hintText: templateHint,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Biến: {old} (tên cũ), ${templateVars.map((v) => "{$v}").join(", ")}",
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: AppTextField(label: "Tìm", controller: findCtrl),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: "Thay bằng",
                      controller: replaceCtrl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: "Thêm tiền tố",
                      controller: prefixCtrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: "Thêm hậu tố",
                      controller: suffixCtrl,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                children: [
                  _Check("Regex (\$1 = nhóm 1)", regex),
                  _Check("Phân biệt hoa thường", caseSensitive),
                ],
              ),
            ],
            if (error != null)
              Text(error, style: const TextStyle(color: AppColors.error)),
            const Divider(),
            Text(
              "${changing.length} / ${items.length} tên sẽ đổi"
              "${hasClash ? " — có tên bị trùng (đỏ), bỏ tick hoặc sửa quy tắc" : ""}",
              style: TextStyle(
                fontSize: 12,
                color: hasClash ? AppColors.error : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final changes = r.next.isNotEmpty && r.next != r.item.oldName;
                  final on = !skipped.value.contains(r.item.id);
                  final bad = changes && on && clash(r);
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    value: changes && on,
                    onChanged: changes
                        ? (v) => skipped.value = v == true
                              ? ({...skipped.value}..remove(r.item.id))
                              : {...skipped.value, r.item.id}
                        : null,
                    title: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: r.item.oldName,
                            style: TextStyle(
                              color: changes
                                  ? AppColors.textMuted
                                  : AppColors.textMain,
                              decoration: changes
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (changes)
                            TextSpan(
                              text: "  →  ${r.next}",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: bad
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                        ],
                      ),
                    ),
                    subtitle: r.item.subtitle.isEmpty
                        ? null
                        : Text(
                            r.item.subtitle,
                            style: const TextStyle(fontSize: 11),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Đổi ${changing.length} tên",
          size: ButtonSize.small,
          variant: ButtonVariant.primary,
          isDisabled: changing.isEmpty || hasClash || error != null,
          onPressed: () => Navigator.pop(context, {
            for (final r in changing) r.item.id: r.next,
          }),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  final String label;
  final ValueNotifier<bool> value;

  const _Check(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Checkbox(value: value.value, onChanged: (v) => value.value = v ?? false),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
