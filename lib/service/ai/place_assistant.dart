import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/service/ai/ai_runner.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/catalog_assistant.dart';
import 'package:component_companion/service/ai/gemini_client.dart';
import 'package:component_companion/util/keyword_matcher.dart';

/// 1 ngăn có thể cất linh kiện.
class PlaceSlot {
  final StorageTray tray;
  final int compartment;

  const PlaceSlot(this.tray, this.compartment);

  /// Mã ngắn gửi cho AI, VD "12:1" (id khay : ngăn).
  String get key => "${tray.id}:$compartment";

  String get label => tray.compartmentLabel(compartment);

  /// Thể tích 1 ngăn (mm³).
  double get volume {
    final t = tray.trayType.target;
    if (t == null) return 0;
    final sizes = tray.compartmentSizes();
    final slots = compartment < sizes.length ? sizes[compartment] : 1;
    return t.widthMm * t.depthMm * t.heightMm / t.compartmentCount * slots;
  }
}

/// 1 gợi ý chỗ cất.
class PlaceSuggestion {
  final PlaceSlot slot;
  final double score;
  final List<String> reasons;
  final String model;

  const PlaceSuggestion(
    this.slot, {
    this.score = 0,
    this.reasons = const [],
    this.model = "",
  });

  bool get fromAi => model.isNotEmpty;
}

/// Gợi ý ngăn cất cho 1 biến thể: chấm điểm theo luật (chạy ngay, không cần
/// mạng) và hỏi AI trên các ngăn điểm cao nhất.
class PlaceAssistant {
  /// Từ khoá linh kiện cồng kềnh (module, bo mạch...) => nên cất khay to.
  static const bulkyKeywords = [
    "module",
    "mạch",
    "board",
    "kit",
    "arduino",
    "esp32",
    "esp8266",
    "raspberry",
    "màn hình",
    "lcd",
    "oled",
    "tft",
    "động cơ",
    "motor",
    "servo",
    "relay",
    "pin ",
    "sạc",
    "nguồn",
    "loa",
    "quạt",
    "breadboard",
    "testboard",
    "dây",
    "cáp",
  ];

  /// Ngăn từ 1 lít trở lên coi là "to".
  static const largeVolume = 1000000.0;

  final List<StorageTray> trays;

  PlaceAssistant(this.trays);

  List<PlaceSlot> get slots => [
    for (final t in trays)
      for (var i = 0; i < t.compartmentCount; i++) PlaceSlot(t, i),
  ];

  static String _text(ComponentVariant v) {
    final c = v.component.target;
    return [
      c?.name,
      c?.type.target?.name,
      c?.category.target?.name,
      c?.description,
    ].whereType<String>().join(" ").toLowerCase();
  }

  static bool isBulky(ComponentVariant v) {
    final text = KeywordMatcher.normalize(_text(v));
    return bulkyKeywords.any((k) => text.contains(KeywordMatcher.normalize(k)));
  }

  /// Các ngăn xếp theo điểm từ cao xuống thấp.
  List<PlaceSuggestion> rank(ComponentVariant variant) {
    final component = variant.component.target;
    final typeId = component?.type.targetId ?? 0;
    final categoryId = component?.category.targetId ?? 0;
    final bulky = isBulky(variant);
    final centers = {
      for (final t in trays)
        t.id: (
          x: t.xMm + t.frontWidthMm / 2,
          y: t.yMm + t.frontHeightMm / 2,
          r: (t.frontWidthMm + t.frontHeightMm) / 2,
        ),
    };

    final results = <PlaceSuggestion>[];
    for (final slot in slots) {
      final reasons = <String>[];
      var score = 0.0;
      final here = slot.tray.variants.where((v) => v.id != variant.id).toList();
      final inSlot = here
          .where((v) => v.compartmentIndex == slot.compartment)
          .toList();
      if (inSlot.isEmpty) {
        score += 3;
        reasons.add("ngăn trống");
      } else {
        score -= 2.0 * inSlot.length;
      }

      final large = slot.volume >= largeVolume;
      if (bulky && large) {
        score += 2;
        reasons.add("linh kiện cồng kềnh, khay to");
      } else if (!bulky && !large) {
        score += 2;
        reasons.add("linh kiện nhỏ, ngăn nhỏ");
      } else if (bulky && !large) {
        score -= 2;
      }

      // Cùng khay
      final sameTypeHere = here.where(
        (v) => typeId != 0 && v.component.target?.type.targetId == typeId,
      );
      if (sameTypeHere.isNotEmpty) {
        score += 4;
        reasons.add("cùng khay với ${sameTypeHere.first.fullLabel}");
      }

      // Khay lân cận
      final c = centers[slot.tray.id]!;
      var neighborType = 0;
      var neighborCategory = 0;
      for (final other in trays) {
        if (other.id == slot.tray.id) continue;
        final o = centers[other.id]!;
        final dx = o.x - c.x;
        final dy = o.y - c.y;
        if (dx * dx + dy * dy > (c.r + o.r) * (c.r + o.r)) continue;
        for (final v in other.variants) {
          final comp = v.component.target;
          if (typeId != 0 && comp?.type.targetId == typeId) {
            neighborType++;
          } else if (categoryId != 0 && comp?.category.targetId == categoryId) {
            neighborCategory++;
          }
        }
      }
      if (neighborType > 0) {
        score += 3;
        reasons.add("gần linh kiện cùng loại");
      } else if (neighborCategory > 0) {
        score += 1.5;
        reasons.add("gần linh kiện cùng danh mục");
      }

      if (slot.tray.hasLed) {
        score += 1;
      } else {
        reasons.add("khay chưa gắn LED");
        score -= 1;
      }
      results.add(PlaceSuggestion(slot, score: score, reasons: reasons));
    }
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byY = a.slot.tray.yMm.compareTo(b.slot.tray.yMm);
      return byY != 0 ? byY : a.slot.tray.xMm.compareTo(b.slot.tray.xMm);
    });
    return results;
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), " ").trim();

  /// Prompt hỏi AI chọn 1 trong [candidates].
  String buildPrompt(
    ComponentVariant variant,
    List<PlaceSuggestion> candidates,
  ) {
    final c = variant.component.target;
    final buffer = StringBuffer()
      ..writeln(
        "Bạn là trợ lý sắp xếp kho linh kiện điện tử cá nhân (tiếng Việt).",
      )
      ..writeln(
        "Chọn 1 ngăn phù hợp nhất để cất linh kiện dưới đây: vừa kích thước, "
        "để gần linh kiện cùng loại / hay dùng cùng nhau, ưu tiên ngăn trống, "
        "không để linh kiện nhỏ chiếm khay to khi còn ngăn nhỏ phù hợp.",
      )
      ..writeln()
      ..writeln("Linh kiện:")
      ..writeln("- Tên: ${_clean(variant.fullLabel)}");
    if (c?.type.target?.name case final String type) {
      buffer.writeln("- Loại: $type");
    }
    if (c?.category.target?.name case final String category) {
      buffer.writeln("- Danh mục: $category");
    }
    if ((c?.description ?? "").trim().isNotEmpty) {
      buffer.writeln("- Mô tả: ${_clean(c!.description)}");
    }
    if (variant.stock != null) buffer.writeln("- Số lượng: ${variant.stock}");
    buffer
      ..writeln()
      ..writeln(
        "Các ngăn (mã | ngăn | kích thước ngăn | đang chứa | lân cận):",
      );
    for (final s in candidates) {
      final slot = s.slot;
      final type = slot.tray.trayType.target;
      final inSlot = slot.tray.variants
          .where(
            (v) => v.compartmentIndex == slot.compartment && v.id != variant.id,
          )
          .map((v) => v.fullLabel)
          .take(5)
          .join(", ");
      final size = type == null
          ? "?"
          : "${type.name}, ~${(slot.volume / 1000).round()} cm³";
      buffer.writeln(
        "- ${slot.key} | ${slot.label} | $size | "
        "${inSlot.isEmpty ? "trống" : inSlot} | ${s.reasons.join("; ")}",
      );
    }
    buffer
      ..writeln()
      ..writeln("Chỉ trả lời JSON, không giải thích thêm:")
      ..writeln('{"slot": "<mã ngăn>", "reason": "<lý do ngắn, tiếng Việt>"}');
    return buffer.toString();
  }

  PlaceSuggestion parse(
    String text,
    List<PlaceSuggestion> candidates, {
    String model = "",
  }) {
    final json = CatalogAssistant.extractJson(text);
    final key = json["slot"]?.toString().trim() ?? "";
    final picked = candidates.where((s) => s.slot.key == key).firstOrNull;
    if (picked == null) {
      throw ValidationException(
        "AI chọn ngăn không có trong danh sách: '$key'",
      );
    }
    final reason = json["reason"] is String
        ? (json["reason"] as String).trim()
        : "";
    return PlaceSuggestion(
      picked.slot,
      score: picked.score,
      reasons: [if (reason.isNotEmpty) reason],
      model: model,
    );
  }

  /// Hỏi AI chọn trong [limit] ngăn điểm cao nhất.
  Future<PlaceSuggestion> ask(
    ComponentVariant variant,
    AiSettings settings, {
    int limit = 30,
    void Function(String model)? onTry,
    GeminiClient? client,
  }) {
    final candidates = rank(variant).take(limit).toList();
    if (candidates.isEmpty) {
      throw ValidationException("Kho chưa có khay nào");
    }
    return askModels(
      buildPrompt(variant, candidates),
      settings,
      (text, model) => parse(text, candidates, model: model),
      onTry: onTry,
      client: client,
    );
  }
}
