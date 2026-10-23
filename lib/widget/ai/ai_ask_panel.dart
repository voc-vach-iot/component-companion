import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/service/ai/ai_runner.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:url_launcher/url_launcher.dart';

/// Phần hỏi AI dùng chung: chế độ API => gọi lần lượt các model ngay khi
/// mở; lỗi hết / chế độ hỏi tay => sao chép prompt rồi dán câu trả lời.
class AiAskPanel<T> extends HookWidget {
  final String prompt;
  final AiSettings settings;
  final Future<T> Function(void Function(String model) onTry) ask;

  /// Đọc câu trả lời dán tay (ném [AppException] nếu hỏng).
  final T Function(String text) parse;
  final ValueChanged<T> onResult;

  const AiAskPanel({
    super.key,
    required this.prompt,
    required this.settings,
    required this.ask,
    required this.parse,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final manual = useState(
      settings.mode == AiMode.copyPrompt || !settings.canCallApi,
    );
    final running = useState(false);
    final trying = useState<String?>(null);
    final failure = useState<AiFailedException?>(null);
    final answerCtrl = useTextEditingController();
    final parseError = useState<String?>(null);

    Future<void> callApi() async {
      running.value = true;
      failure.value = null;
      try {
        final result = await ask((m) => trying.value = m);
        if (context.mounted) onResult(result);
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

    useEffect(() {
      if (!manual.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) => callApi());
      }
      return null;
    }, const []);

    void readAnswer() {
      try {
        final result = parse(answerCtrl.text);
        parseError.value = null;
        onResult(result);
      } on AppException catch (e) {
        parseError.value = e.message;
      }
    }

    if (running.value) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            "Đang hỏi ${trying.value ?? "..."}",
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      );
    }
    if (!manual.value) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (failure.value case final f?)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${f.fatal ? "Không gọi được API" : "Không model nào trả lời được"} — "
              "hãy sao chép prompt để hỏi tay.\n${f.summary}",
              style: const TextStyle(fontSize: 12),
            ),
          )
        else if (!settings.canCallApi)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              "Chưa nhập API key Gemini (trang Dữ liệu > Trợ lý AI) — "
              "sao chép prompt để hỏi tay.",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        const Text(
          "1. Sao chép prompt, dán vào Gemini / ChatGPT.  "
          "2. Dán câu trả lời (JSON) vào ô dưới rồi bấm \"Đọc câu trả lời\".",
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              label: "Sao chép prompt",
              icon: Icons.copy_rounded,
              size: ButtonSize.small,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: prompt));
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
            if (settings.canCallApi)
              AppButton(
                label: "Thử gọi API lại",
                icon: Icons.refresh_rounded,
                size: ButtonSize.small,
                variant: ButtonVariant.secondary,
                onPressed: callApi,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text("Xem prompt", style: TextStyle(fontSize: 13)),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: SelectableText(
                  prompt,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        TextField(
          controller: answerCtrl,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: "Dán câu trả lời của AI vào đây",
            errorText: parseError.value,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            label: "Đọc câu trả lời",
            size: ButtonSize.small,
            variant: ButtonVariant.primary,
            onPressed: readAnswer,
          ),
        ),
      ],
    );
  }
}
