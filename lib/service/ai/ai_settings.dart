import 'package:component_companion/data/app_setting_repository.dart';

/// Cách dùng AI: gọi API trực tiếp hay chỉ sao chép prompt để tự dán vào
/// Gemini / ChatGPT rồi dán câu trả lời lại.
enum AiMode {
  api("Gọi API Gemini"),
  copyPrompt("Sao chép prompt");

  final String label;
  const AiMode(this.label);
}

/// Cấu hình trợ lý AI (lưu ở bảng cài đặt; API key không vào file sao lưu).
class AiSettings {
  static const apiKeyKey = "ai.apiKey";
  static const modeKey = "ai.mode";
  static const modelsKey = "ai.models";

  /// Khoá không đưa vào file sao lưu và giữ lại khi khôi phục.
  static const secretKeys = {apiKeyKey};

  /// Model thử lần lượt, từ mạnh tới yếu (các model có hạn mức miễn phí ở
  /// Google AI Studio). Sửa được ở trang Dữ liệu / lấy lại từ Google.
  static const defaultModels = [
    "gemini-3.8-flash",
    "gemini-3.7-flash",
    "gemini-3.6-flash",
    "gemini-3-flash",
    "gemini-2.5-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash-lite",
    "gemma-4-31b-it",
    "gemma-4-26b-it",
  ];

  final String apiKey;
  final AiMode mode;
  final List<String> models;

  const AiSettings({
    this.apiKey = "",
    this.mode = AiMode.api,
    this.models = defaultModels,
  });

  bool get canCallApi => apiKey.trim().isNotEmpty && models.isNotEmpty;

  static AiSettings load(AppSettingRepository repo) {
    final models = (repo.get(modelsKey) ?? "")
        .split(RegExp(r'[\n,]'))
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
    return AiSettings(
      apiKey: repo.get(apiKeyKey) ?? "",
      mode:
          AiMode.values.where((m) => m.name == repo.get(modeKey)).firstOrNull ??
          AiMode.api,
      models: models.isEmpty ? defaultModels : models,
    );
  }

  void save(AppSettingRepository repo) {
    repo.set(apiKeyKey, apiKey.trim());
    repo.set(modeKey, mode.name);
    repo.set(modelsKey, models.join("\n"));
  }

  /// Xếp các model lấy từ Google: chỉ model sinh chữ (bỏ TTS, ảnh, live,
  /// embedding...), Gemini trước Gemma; phiên bản mới trước; cùng phiên bản
  /// thì pro > flash > flash-lite; bản preview / exp xếp sau bản chính thức.
  static List<String> rankModels(Iterable<String> names) {
    const skip = [
      "tts",
      "image",
      "audio",
      "live",
      "embedding",
      "robotics",
      "computer-use",
      "transcribe",
      "translate",
      "veo",
      "lyria",
      "imagen",
      "aqa",
      "learnlm",
      "nano-banana",
      "omni",
      "deep-research",
      "native",
    ];
    final usable = names
        .map((n) => n.replaceFirst("models/", ""))
        .where((n) => n.startsWith("gemini-") || n.startsWith("gemma-"))
        .where((n) => !skip.any(n.contains))
        .toSet()
        .toList();

    (double, int, int, int) score(String name) {
      final family = name.startsWith("gemini-") ? 0 : 1;
      final version =
          double.tryParse(
            RegExp(r'^(?:gemini|gemma)-(\d+(?:\.\d+)?)').firstMatch(name)?[1] ??
                "",
          ) ??
          0;
      final tier = name.contains("flash-lite") || name.contains("-lite")
          ? 2
          : name.contains("flash")
          ? 1
          : 0;
      final unstable = RegExp(r'preview|exp|latest|\d{2}-\d{2}').hasMatch(name)
          ? 1
          : 0;
      // Gemma: số tham số lớn hơn trước (31b > 26b)
      final size =
          int.tryParse(RegExp(r'-(\d+)b').firstMatch(name)?[1] ?? "") ?? 0;
      return (-version, family * 10 + tier, unstable, -size);
    }

    usable.sort((a, b) {
      final sa = score(a), sb = score(b);
      // Gemini trước Gemma bất kể phiên bản
      final fa = a.startsWith("gemini-") ? 0 : 1;
      final fb = b.startsWith("gemini-") ? 0 : 1;
      if (fa != fb) return fa.compareTo(fb);
      for (final c in [
        sa.$1.compareTo(sb.$1),
        sa.$2.compareTo(sb.$2),
        sa.$3.compareTo(sb.$3),
        sa.$4.compareTo(sb.$4),
      ]) {
        if (c != 0) return c;
      }
      return a.compareTo(b);
    });
    return usable;
  }
}
