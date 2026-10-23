import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/app_setting_repository.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/gemini_client.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cài đặt trợ lý AI: API key, cách dùng, danh sách model thử lần lượt.
class AiSettingsForm extends HookConsumerWidget {
  const AiSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(appSettingRepositoryProvider);
    final initial = useMemoized(() => AiSettings.load(repo));
    final keyCtrl = useTextEditingController(text: initial.apiKey);
    final modelsCtrl = useTextEditingController(
      text: initial.models.join("\n"),
    );
    final mode = useState(initial.mode);
    final showKey = useState(false);
    final busy = useState<String?>(null);
    final testLog = useState<String?>(null);

    AiSettings current() => AiSettings(
      apiKey: keyCtrl.text.trim(),
      mode: mode.value,
      models: modelsCtrl.text
          .split(RegExp(r'[\n,]'))
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList(),
    );

    void save({bool notify = true}) {
      current().save(repo);
      if (notify) {
        AppSnackBar.show(
          context,
          message: "Đã lưu cài đặt AI",
          type: SnackBarType.success,
        );
      }
    }

    Future<void> fetchModels() async {
      final key = keyCtrl.text.trim();
      if (key.isEmpty) return;
      busy.value = "Đang lấy danh sách model...";
      try {
        final ranked = AiSettings.rankModels(
          await GeminiClient(key).listModels(),
        );
        if (!context.mounted) return;
        if (ranked.isEmpty) {
          AppSnackBar.show(
            context,
            message: "Google không trả về model sinh chữ nào",
            type: SnackBarType.error,
          );
          return;
        }
        modelsCtrl.text = ranked.join("\n");
        save(notify: false);
        AppSnackBar.show(
          context,
          message:
              "Đã lấy ${ranked.length} model. Xoá bớt model không có hạn mức "
              "miễn phí (VD bản Pro) để đỡ phải chờ thử.",
          type: SnackBarType.success,
          duration: const Duration(seconds: 6),
        );
      } on GeminiException catch (e) {
        if (context.mounted) {
          AppSnackBar.show(
            context,
            message: "Không lấy được danh sách: ${e.summary}",
            type: SnackBarType.error,
          );
        }
      } finally {
        if (context.mounted) busy.value = null;
      }
    }

    Future<void> test() async {
      final settings = current();
      if (!settings.canCallApi) return;
      save(notify: false);
      final client = GeminiClient(settings.apiKey);
      final log = <String>[];
      for (final model in settings.models) {
        busy.value = "Đang thử $model...";
        try {
          await client.generate(model, 'Trả lời đúng JSON: {"ok": true}');
          log.add("✅ $model trả lời được");
          break;
        } on GeminiException catch (e) {
          log.add("❌ $model: ${e.summary}");
          if (e.fatal) break;
        }
      }
      if (!context.mounted) return;
      busy.value = null;
      testLog.value = log.join("\n");
    }

    final hasKey = useValueListenable(keyCtrl).text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: keyCtrl,
                obscureText: !showKey.value,
                decoration: InputDecoration(
                  labelText: "API key Gemini (Google AI Studio)",
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      showKey.value ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => showKey.value = !showKey.value,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse("https://aistudio.google.com/apikey"),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.key_outlined, size: 16),
              label: const Text("Lấy API key"),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "API key chỉ lưu trên máy này, không đưa vào file sao lưu.",
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        SegmentedButton<AiMode>(
          segments: [
            for (final m in AiMode.values)
              ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {mode.value},
          onSelectionChanged: (v) => mode.value = v.first,
        ),
        const SizedBox(height: 4),
        Text(
          mode.value == AiMode.api
              ? "Gọi lần lượt các model bên dưới (trên xuống); lỗi hết thì chuyển sang sao chép prompt."
              : "Luôn sao chép prompt để tự dán vào Gemini / ChatGPT rồi dán câu trả lời lại.",
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: modelsCtrl,
          minLines: 4,
          maxLines: 10,
          style: const TextStyle(fontFamily: "monospace", fontSize: 13),
          decoration: const InputDecoration(
            labelText: "Model (mỗi dòng 1 model, thử từ trên xuống)",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton(
              label: "Lưu",
              icon: Icons.save_outlined,
              size: ButtonSize.small,
              onPressed: save,
            ),
            AppButton(
              label: "Lấy danh sách model từ Google",
              icon: Icons.cloud_download_outlined,
              size: ButtonSize.small,
              variant: ButtonVariant.secondary,
              isDisabled: !hasKey || busy.value != null,
              onPressed: fetchModels,
            ),
            AppButton(
              label: "Thử kết nối",
              icon: Icons.network_check_rounded,
              size: ButtonSize.small,
              variant: ButtonVariant.secondary,
              isDisabled: !hasKey || busy.value != null,
              onPressed: test,
            ),
            TextButton(
              onPressed: () =>
                  modelsCtrl.text = AiSettings.defaultModels.join("\n"),
              child: const Text("Danh sách mặc định"),
            ),
            if (busy.value != null)
              Text(
                busy.value!,
                style: const TextStyle(color: AppColors.textMuted),
              ),
          ],
        ),
        if (testLog.value != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(
              testLog.value!,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
