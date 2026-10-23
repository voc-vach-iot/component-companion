import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/app_setting_repository.dart';
import 'package:component_companion/data/icon_repository.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/service/ai/ai_runner.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/svg_assistant.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Nhờ AI vẽ icon SVG cho [subject]. Trả về mã SVG (null nếu huỷ); có thể lưu
/// luôn vào thư viện icon.
class AiSvgDialog extends HookConsumerWidget {
  final String subject;

  const AiSvgDialog({super.key, required this.subject});

  static Future<String?> show(
    BuildContext context, {
    required String subject,
  }) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AiSvgDialog(subject: subject),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = useMemoized(
      () => AiSettings.load(ref.read(appSettingRepositoryProvider)),
    );
    final subjectCtrl = useTextEditingController(text: subject);
    final manual = useState(
      settings.mode == AiMode.copyPrompt || !settings.canCallApi,
    );
    final running = useState(false);
    final trying = useState<String?>(null);
    final failure = useState<AiFailedException?>(null);
    final answerCtrl = useTextEditingController();
    final parseError = useState<String?>(null);
    final result =
        useState<({String svg, String name, List<String> keywords})?>(null);
    final saveToLibrary = useState(true);

    String prompt() => SvgAssistant.buildPrompt(subjectCtrl.text);

    Future<void> callApi() async {
      if (subjectCtrl.text.trim().isEmpty) return;
      running.value = true;
      failure.value = null;
      try {
        final r = await askModels(
          prompt(),
          settings,
          (text, _) => SvgAssistant.parse(text),
          onTry: (m) => trying.value = m,
        );
        if (context.mounted) result.value = r;
      } on AiFailedException catch (e) {
        if (!context.mounted) return;
        failure.value = e;
        manual.value = true;
      } finally {
        if (context.mounted) {
          running.value = false;
          trying.value = null;
        }
      }
    }

    void readAnswer() {
      try {
        result.value = SvgAssistant.parse(answerCtrl.text);
        parseError.value = null;
      } on AppException catch (e) {
        parseError.value = e.message;
      }
    }

    Future<void> accept() async {
      final r = result.value!;
      if (saveToLibrary.value) {
        final name = r.name.isNotEmpty ? r.name : subjectCtrl.text.trim();
        // Trùng tên trong thư viện => vẫn dùng icon, chỉ báo lỗi lưu
        await IconRepository()
            .save(
              IconAsset(
                name: name,
                svg: r.svg,
                pack: IconRepository.userPack,
                keywords: r.keywords,
              ),
            )
            .withToast(context);
      }
      if (context.mounted) Navigator.pop(context, r.svg);
    }

    Widget body() {
      if (running.value) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              "Đang nhờ ${trying.value ?? "..."} vẽ",
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        );
      }
      if (result.value case final r?) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 16,
              children: [
                for (final size in const [64.0, 32.0, 20.0])
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AppSvgIcon(svg: r.svg, size: size),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (r.name.isNotEmpty) Text(r.name),
            CheckboxListTile(
              dense: true,
              value: saveToLibrary.value,
              onChanged: (v) => saveToLibrary.value = v ?? false,
              title: const Text("Lưu vào thư viện icon (bộ \"Của tôi\")"),
            ),
          ],
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: subjectCtrl,
            decoration: const InputDecoration(
              labelText: "Vẽ icon cho",
              hintText: "VD Thẻ nhớ MicroSD, Còi buzzer",
            ),
          ),
          const SizedBox(height: 10),
          if (failure.value case final f?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "${f.fatal ? "Không gọi được API" : "Không model nào vẽ được"} — "
                "sao chép prompt để hỏi tay.\n${f.summary}",
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          if (manual.value) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: "Sao chép prompt",
                  icon: Icons.copy_rounded,
                  size: ButtonSize.small,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: prompt()));
                    if (context.mounted) {
                      AppSnackBar.show(
                        context,
                        message: "Đã sao chép prompt",
                        type: SnackBarType.success,
                      );
                    }
                  },
                ),
                AppButton(
                  label: "Mở Gemini",
                  icon: Icons.open_in_new,
                  size: ButtonSize.small,
                  variant: ButtonVariant.secondary,
                  onPressed: () => launchUrl(
                    Uri.parse("https://gemini.google.com/app"),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: answerCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: "Dán câu trả lời (JSON hoặc mã <svg>) vào đây",
                errorText: parseError.value,
              ),
            ),
          ],
        ],
      );
    }

    final hasResult = result.value != null;
    return AppAlertDialog(
      title: "Nhờ AI vẽ icon",
      // Đang gọi AI: đóng = bỏ lượt gọi; có kết quả: đóng = không dùng
      cancelLabel: running.value
          ? "Dừng & đóng"
          : hasResult
          ? "Bỏ kết quả"
          : "Đóng",
      size: AlertDialogSize.small,
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(child: body()),
      ),
      actions: [
        if (hasResult)
          AppButton(
            label: "Vẽ lại",
            size: ButtonSize.small,
            variant: ButtonVariant.secondary,
            onPressed: () => result.value = null,
          ),
        if (hasResult)
          AppButton(
            label: "Dùng icon này",
            size: ButtonSize.small,
            variant: ButtonVariant.primary,
            onPressed: accept,
          )
        else if (!running.value) ...[
          if (settings.canCallApi)
            AppButton(
              label: "Gọi AI vẽ",
              size: ButtonSize.small,
              variant: manual.value
                  ? ButtonVariant.secondary
                  : ButtonVariant.primary,
              onPressed: callApi,
            ),
          if (manual.value)
            AppButton(
              label: "Đọc câu trả lời",
              size: ButtonSize.small,
              variant: ButtonVariant.primary,
              onPressed: readAnswer,
            ),
        ],
      ],
    );
  }
}
