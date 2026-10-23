import 'dart:convert';
import 'dart:io';

import 'package:component_companion/data/app_setting_repository.dart';
import 'package:component_companion/model/entities/app_setting.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/ai/catalog_assistant.dart';
import 'package:component_companion/service/ai/gemini_client.dart';
import 'package:component_companion/service/ai/svg_assistant.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

/// Client giả: mỗi model trả lời / lỗi theo bảng.
class _FakeClient extends GeminiClient {
  final Map<String, Object> answers;
  final calls = <String>[];

  _FakeClient(this.answers) : super("key");

  @override
  Future<String> generate(
    String model,
    String prompt, {
    bool json = true,
  }) async {
    calls.add(model);
    final answer = answers[model];
    if (answer is GeminiException) throw answer;
    if (answer is String) return answer;
    throw const GeminiException("Not found", status: 404);
  }
}

void main() {
  test(
    "xếp model từ Google: bỏ TTS/ảnh/live, mới trước, Gemini trước Gemma",
    () {
      final ranked = AiSettings.rankModels([
        "models/gemini-2.5-flash",
        "models/gemini-2.5-flash-preview-tts",
        "models/gemini-3.1-flash-lite",
        "models/gemma-4-26b-it",
        "models/gemini-3.8-flash",
        "models/gemini-embedding-001",
        "models/gemma-4-31b-it",
        "models/gemini-2.5-flash-image",
        "models/gemini-3.5-flash-lite",
        "models/gemini-3.8-flash-live",
      ]);
      expect(ranked, [
        "gemini-3.8-flash",
        "gemini-3.5-flash-lite",
        "gemini-3.1-flash-lite",
        "gemini-2.5-flash",
        "gemma-4-31b-it",
        "gemma-4-26b-it",
      ]);
    },
  );

  test("đọc SVG AI vẽ: JSON hoặc thẻ <svg> trần", () {
    final json = SvgAssistant.parse(
      '{"svg": "<svg viewBox=\\"0 0 24 24\\"><path d=\\"M4 4h16\\"/></svg>", '
      '"name": "Thẻ nhớ", "keywords": ["MicroSD"]}',
    );
    expect(json.svg, '<svg viewBox="0 0 24 24"><path d="M4 4h16"/></svg>');
    expect(json.name, "Thẻ nhớ");
    expect(json.keywords, ["microsd"]);

    final raw = SvgAssistant.parse(
      "Đây:\n```svg\n<svg viewBox='0 0 24 24'><circle cx='12' cy='12' r='4'/></svg>\n```",
    );
    expect(raw.svg, startsWith("<svg"));
    expect(raw.svg, endsWith("</svg>"));
    expect(() => SvgAssistant.parse("không vẽ được"), throwsA(anything));
  });

  group("với DB", () {
    late ObjectboxService db;
    late Directory dir;
    late CatalogAssistant assistant;
    late int passive;
    late int resistor;

    setUp(() async {
      (db, dir) = await openTestDb();
      passive = db.get<Category>().put(
        Category(
          name: "Linh kiện thụ động",
          colorValue: 0xFFBAE1FF,
          keywords: ["điện trở", "tụ"],
        ),
      );
      resistor = db.get<ComponentType>().put(
        ComponentType(name: "Điện trở cắm", keywords: ["điện trở"])
          ..category.targetId = passive,
      );
      assistant = CatalogAssistant(
        categories: db.get<Category>().getAll(),
        types: db.get<ComponentType>().getAll(),
      );
    });
    tearDown(() => closeTestDb(db, dir));

    test("prompt có danh mục / loại có sẵn và linh kiện cần phân loại", () {
      final prompt = assistant.buildPrompt(
        name: "Thẻ nhớ MicroSD 32GB",
        attributes: ["Dung lượng"],
      );
      expect(prompt, contains("Thẻ nhớ MicroSD 32GB"));
      expect(prompt, contains("- Linh kiện thụ động | điện trở, tụ"));
      expect(
        prompt,
        contains("- Điện trở cắm | Linh kiện thụ động | điện trở"),
      );
      expect(prompt, contains("Thuộc tính: Dung lượng"));
    });

    test("đọc câu trả lời: khớp có sẵn, tạo mới, JSON trong ```", () {
      final s = assistant.parse('''Đây là kết quả:
```json
{
  "category": {"existing": "linh kiện thụ động", "new": null,
               "addKeywords": ["Tụ", "resistor"]},
  "type": {"existing": null,
           "new": {"name": "Tụ gốm", "keywords": ["tụ gốm", "ceramic"],
                   "attributes": ["Điện dung"],
                   "iconSvg": "abc <svg viewBox=\\"0 0 24 24\\"><path d=\\"M2 12h20\\"/></svg> xyz"}},
  "note": "Tụ gốm thuộc linh kiện thụ động"
}
```''');
      expect(s.category.existing?.id, passive);
      // "tụ" đã có => chỉ thêm "resistor"
      expect(s.category.addKeywords, ["resistor"]);
      expect(s.type.isNew, isTrue);
      expect(s.type.name, "Tụ gốm");
      expect(s.type.attributes, ["Điện dung"]);
      expect(s.type.iconSvg, startsWith("<svg"));
      expect(s.type.iconSvg, endsWith("</svg>"));
      expect(s.note, isNotEmpty);

      // Tên "mới" trùng loại có sẵn => dùng loại có sẵn
      final dup = assistant.parse(
        '{"category": {"existing": null, "new": null}, '
        '"type": {"existing": null, "new": {"name": "ĐIỆN TRỞ CẮM"}}}',
      );
      expect(dup.type.existing?.id, resistor);
      expect(dup.category.isEmpty, isTrue);

      expect(
        () => assistant.parse("xin lỗi tôi không biết"),
        throwsA(anything),
      );
    });

    test("gọi lần lượt model: lỗi / JSON hỏng thì thử model sau", () async {
      final client = _FakeClient({
        "m1": const GeminiException("quota", status: 429),
        "m2": "không phải JSON",
        "m3": jsonEncode({
          "category": {"existing": "Linh kiện thụ động"},
          "type": {"existing": "Điện trở cắm"},
        }),
      });
      final s = await assistant.ask(
        "prompt",
        const AiSettings(apiKey: "k", models: ["m1", "m2", "m3", "m4"]),
        client: client,
      );
      expect(client.calls, ["m1", "m2", "m3"]);
      expect(s.model, "m3");
      expect(s.type.existing?.id, resistor);
    });

    test("lỗi hết => AiFailedException; sai API key thì dừng ngay", () async {
      final all = _FakeClient({});
      await expectLater(
        assistant.ask(
          "p",
          const AiSettings(apiKey: "k", models: ["a", "b"]),
          client: all,
        ),
        throwsA(
          isA<AiFailedException>().having((e) => e.attempts.length, "n", 2),
        ),
      );

      final badKey = _FakeClient({
        "a": const GeminiException("bad", status: 403, fatal: true),
      });
      await expectLater(
        assistant.ask(
          "p",
          const AiSettings(apiKey: "k", models: ["a", "b"]),
          client: badKey,
        ),
        throwsA(isA<AiFailedException>().having((e) => e.fatal, "fatal", true)),
      );
      expect(badKey.calls, ["a"]);
    });

    test(
      "áp dụng: tạo danh mục + loại mới, bỏ từ khoá đã thuộc nơi khác",
      () async {
        final s = assistant.parse(
          jsonEncode({
            "category": {
              "existing": null,
              "new": {
                "name": "Lưu trữ",
                "color": "teal",
                "keywords": ["thẻ nhớ", "điện trở"],
              },
            },
            "type": {
              "existing": null,
              "new": {
                "name": "Thẻ nhớ",
                "keywords": ["thẻ nhớ", "microsd"],
                "attributes": ["Dung lượng"],
              },
            },
          }),
        );
        final ids = await CatalogAssistant.apply(s);
        final category = db.get<Category>().get(ids.categoryId)!;
        expect(category.name, "Lưu trữ");
        expect(category.keywords, [
          "thẻ nhớ",
        ]); // "điện trở" đã thuộc danh mục khác
        final type = db.get<ComponentType>().get(ids.typeId)!;
        expect(type.category.targetId, ids.categoryId);
        expect(type.attributeTemplate, ["Dung lượng"]);
        expect(type.keywords, ["thẻ nhớ", "microsd"]);
      },
    );

    test("áp dụng: dùng có sẵn + thêm từ khoá", () async {
      final s = assistant.parse(
        jsonEncode({
          "category": {
            "existing": "Linh kiện thụ động",
            "addKeywords": ["resistor"],
          },
          "type": {"existing": "Điện trở cắm"},
        }),
      );
      final ids = await CatalogAssistant.apply(s, useType: false);
      expect(ids, (categoryId: passive, typeId: 0));
      expect(db.get<Category>().get(passive)!.keywords, contains("resistor"));
    });

    test("API key không vào file sao lưu và còn sau khi khôi phục", () {
      final repo = AppSettingRepository();
      const AiSettings(apiKey: "secret-key", models: ["m1"]).save(repo);
      final transfer = DataTransferService();
      final data = transfer.exportAll();
      final keys = [for (final s in data["settings"] as List) s["key"]];
      expect(keys, isNot(contains(AiSettings.apiKeyKey)));
      expect(keys, contains(AiSettings.modelsKey));

      transfer.replaceAll(data);
      expect(AiSettings.load(repo).apiKey, "secret-key");
      expect(AiSettings.load(repo).models, ["m1"]);
      expect(db.get<AppSetting>().count(), greaterThanOrEqualTo(3));
    });
  });
}
