import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/gemini_client.dart';

/// Kết quả 1 lần thử model.
typedef AiAttempt = ({String model, String? error});

/// Mọi model đều lỗi => dùng prompt để hỏi tay.
class AiFailedException implements Exception {
  final List<AiAttempt> attempts;
  final bool fatal;

  const AiFailedException(this.attempts, {this.fatal = false});

  String get summary =>
      attempts.map((a) => "${a.model}: ${a.error ?? "OK"}").join("\n");
}

/// Gọi lần lượt các model trong [settings] tới khi có câu trả lời [parse] đọc
/// được (parse ném [AppException] = câu trả lời hỏng => thử model sau).
/// Sai API key / mất mạng => dừng ngay. Lỗi hết => [AiFailedException].
Future<T> askModels<T>(
  String prompt,
  AiSettings settings,
  T Function(String text, String model) parse, {
  void Function(String model)? onTry,
  GeminiClient? client,
}) async {
  final gemini = client ?? GeminiClient(settings.apiKey.trim());
  final attempts = <AiAttempt>[];
  for (final model in settings.models) {
    onTry?.call(model);
    try {
      final result = parse(await gemini.generate(model, prompt), model);
      attempts.add((model: model, error: null));
      return result;
    } on GeminiException catch (e) {
      attempts.add((model: model, error: e.summary));
      if (e.fatal) throw AiFailedException(attempts, fatal: true);
    } on AppException catch (e) {
      attempts.add((model: model, error: e.message));
    }
  }
  throw AiFailedException(attempts);
}
