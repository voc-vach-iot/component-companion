import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Lỗi khi gọi Gemini. [fatal] = lỗi không đổi model mà khỏi (sai API key,
/// không có mạng) => dừng thử các model còn lại.
class GeminiException implements Exception {
  final int? status;
  final String message;
  final bool fatal;

  const GeminiException(this.message, {this.status, this.fatal = false});

  /// Mô tả ngắn cho người dùng.
  String get summary => switch (status) {
    429 => "hết lượt / quá giới hạn (429)",
    404 => "model không tồn tại hoặc không hỗ trợ (404)",
    400 when fatal => "API key không hợp lệ (400)",
    400 => "yêu cầu không hợp lệ (400): $message",
    401 || 403 => "API key không hợp lệ hoặc không có quyền ($status)",
    final s? when s >= 500 => "máy chủ Google lỗi ($s)",
    _ => message,
  };

  @override
  String toString() => "GeminiException($status): $message";
}

/// Gọi Gemini API (generativelanguage.googleapis.com) bằng HttpClient của
/// dart:io — không cần thêm package.
class GeminiClient {
  static const _host = "generativelanguage.googleapis.com";
  static const timeout = Duration(seconds: 60);

  final String apiKey;

  GeminiClient(this.apiKey);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String> query = const {},
    Object? body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.https(_host, path, query);
      final request = await client.openUrl(method, uri).timeout(timeout);
      request.headers
        ..set("x-goog-api-key", apiKey)
        ..contentType = ContentType.json;
      if (body != null) request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(timeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      Map<String, dynamic> json;
      try {
        json = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        json = const {};
      }
      if (response.statusCode != 200) {
        final error = json["error"];
        final message = error is Map
            ? "${error["message"] ?? error["status"] ?? ""}"
            : text;
        throw GeminiException(
          message.length > 300 ? "${message.substring(0, 300)}…" : message,
          status: response.statusCode,
          // Sai API key Google trả 400 "API key not valid" => đổi model
          // cũng không khỏi
          fatal:
              response.statusCode == 401 ||
              response.statusCode == 403 ||
              RegExp(r'api key', caseSensitive: false).hasMatch(message),
        );
      }
      return json;
    } on SocketException catch (e) {
      throw GeminiException("Không kết nối được: ${e.message}", fatal: true);
    } on TimeoutException {
      throw const GeminiException("Quá thời gian chờ phản hồi");
    } on HandshakeException catch (e) {
      throw GeminiException("Lỗi kết nối bảo mật: ${e.message}", fatal: true);
    } finally {
      client.close(force: true);
    }
  }

  /// Tên các model gọi được generateContent (bỏ tiền tố "models/").
  Future<List<String>> listModels() async {
    final result = <String>[];
    String? pageToken;
    do {
      final json = await _request(
        "GET",
        "/v1beta/models",
        query: {"pageSize": "1000", "pageToken": ?pageToken},
      );
      for (final m in (json["models"] as List? ?? const [])) {
        if (m is! Map) continue;
        final methods = (m["supportedGenerationMethods"] as List? ?? const []);
        if (!methods.contains("generateContent")) continue;
        final name = "${m["name"]}".replaceFirst("models/", "");
        result.add(name);
      }
      pageToken = json["nextPageToken"] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return result;
  }

  /// Gửi [prompt], trả về chữ trả lời. Gemma không hỗ trợ ép JSON nên chỉ
  /// bật [json] cho Gemini.
  Future<String> generate(
    String model,
    String prompt, {
    bool json = true,
  }) async {
    final response = await _request(
      "POST",
      "/v1beta/models/$model:generateContent",
      body: {
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": prompt},
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.3,
          if (json && !model.startsWith("gemma"))
            "responseMimeType": "application/json",
        },
      },
    );
    final candidates = response["candidates"] as List? ?? const [];
    final parts =
        (candidates.firstOrNull as Map?)?["content"]?["parts"] as List? ??
        const [];
    final text = parts
        .whereType<Map>()
        .where((p) => p["thought"] != true)
        .map((p) => "${p["text"] ?? ""}")
        .join();
    if (text.trim().isEmpty) {
      final reason =
          (candidates.firstOrNull as Map?)?["finishReason"] ??
          response["promptFeedback"]?["blockReason"] ??
          "trống";
      throw GeminiException("Model không trả lời ($reason)");
    }
    return text;
  }
}
