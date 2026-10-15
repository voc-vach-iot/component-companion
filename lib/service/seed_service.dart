import 'dart:convert';

import 'package:component_companion/data/icon_repository.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/app_setting.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/icon_csv.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';

/// Nạp dữ liệu mặc định (danh mục, loại linh kiện, thư viện icon) từ
/// `assets/seed/`.
///
/// Mỗi phiên bản seed chỉ chạy 1 lần (lưu trong [AppSetting]). Dữ liệu được
/// gộp theo tên: bản ghi đã tồn tại chỉ được bổ sung các trường còn trống,
/// không ghi đè chỉnh sửa của người dùng.
class SeedService {
  /// Tăng số này khi thêm bước seed mới để người dùng cũ nhận dữ liệu mới.
  /// Mỗi bước chỉ chạy 1 lần:
  /// - 1: danh mục + loại linh kiện mặc định
  /// - 2: mẫu thuộc tính biến thể cho các loại phổ biến
  /// - 3: loại phân theo chức năng (gộp loại tách theo kiểu chân DIP / SOP /
  ///   SMD...), thêm loại IC mới, nạp thư viện icon có sẵn
  static const int seedVersion = 3;
  static const String _seedVersionKey = "seed_version";

  /// Seed v3: loại cũ tách theo kiểu chân => loại theo chức năng. Kiểu chân
  /// nay là thuộc tính biến thể "Đóng gói" của linh kiện.
  /// null = phân loại lại từng linh kiện theo tên (không khớp => [fallbackIcType]).
  static const packageTypeMerges = <String, String?>{
    "Điện trở cắm (1/4W)": "Điện trở",
    "Điện trở vạch": "Điện trở",
    "Điện trở dán (SMD)": "Điện trở",
    "Tụ dán (SMD)": "Tụ gốm",
    "Transistor (TO-92)": "Transistor (BJT)",
    "MOSFET (TO-220)": "MOSFET",
    "LED đơn (3mm/5mm)": "LED đơn",
    "Pin cúc áo (CR2032)": "Pin cúc áo",
    "IC chân cắm (DIP)": null,
    "IC dán (SOP/SOIC)": null,
  };
  static const fallbackIcType = "IC khác";

  /// Loại mới ở seed v3 (thêm cho người dùng cũ nếu chưa có).
  static const v3NewTypes = [
    "IC định thời",
    "IC so sánh điện áp",
    "IC khuếch đại",
    "IC mở rộng chân",
    "IC logic (74HC / CD4000)",
    "Opto / IC cách ly",
    "IC driver",
    "IC khác",
  ];

  static const iconSeedPath = "assets/seed/icons.csv";

  final _db = ObjectboxService.instance;

  Future<void> run() async {
    final settingBox = _db.get<AppSetting>();
    final current = settingBox
        .query(AppSetting_.key.equals(_seedVersionKey))
        .findFirstAndClose();
    final applied = int.tryParse(current?.value ?? "") ?? 0;
    if (applied >= seedVersion) return;

    final categoriesJson = applied < 1
        ? await rootBundle.loadString("assets/seed/categories.json")
        : null;
    final typesJson = await rootBundle.loadString(
      "assets/seed/component_types.json",
    );
    final iconsCsv = applied < 3
        ? await rootBundle.loadString(iconSeedPath)
        : null;

    apply(
      applied: applied,
      categorySeeds: categoriesJson == null
          ? null
          : (jsonDecode(categoriesJson) as List).cast<Map<String, dynamic>>(),
      typeSeeds: (jsonDecode(typesJson) as List).cast<Map<String, dynamic>>(),
      iconsCsv: iconsCsv,
    );
    debugPrint("🌱 Đã nạp dữ liệu seed tới phiên bản $seedVersion");
  }

  /// Chạy các bước seed còn thiếu (tách khỏi [run] để test không cần asset).
  @visibleForTesting
  void apply({
    required int applied,
    required List<Map<String, dynamic>>? categorySeeds,
    required List<Map<String, dynamic>> typeSeeds,
    String? iconsCsv,
  }) {
    _db.store.runInTransaction(TxMode.write, () {
      if (applied < 1) {
        final categoriesByName = _seedCategories(categorySeeds!);
        _seedTypes(typeSeeds, categoriesByName);
      }
      if (applied < 3) _mergePackageTypes(typeSeeds);
      if (applied < 3) _seedAttributeTemplates(typeSeeds);
      _db.get<AppSetting>().put(
        AppSetting(key: _seedVersionKey, value: seedVersion.toString()),
      );
    });
    // Thư viện icon chạy transaction riêng
    if (iconsCsv != null) {
      IconRepository().import(
        IconCsv.decode(iconsCsv, defaultPack: "Có sẵn").icons,
      );
    }
  }

  /// Điền mẫu thuộc tính cho loại đang có mà chưa có mẫu (không tạo lại loại
  /// người dùng đã xoá).
  void _seedAttributeTemplates(List<Map<String, dynamic>> seeds) {
    final templates = {
      for (final seed in seeds)
        _key(seed["name"] as String):
            (seed["attributeTemplate"] as List? ?? const []).cast<String>(),
    };
    final box = _db.get<ComponentType>();
    final types = box.getAll();
    for (final type in types) {
      final template = templates[_key(type.name)];
      if (template != null &&
          template.isNotEmpty &&
          type.attributeTemplate.isEmpty) {
        type.attributeTemplate = [...template];
      }
    }
    box.putMany(types);
  }

  /// Seed v3: gộp loại tách theo kiểu chân vào loại theo chức năng (xem
  /// [packageTypeMerges]) và thêm các loại mới [v3NewTypes].
  void _mergePackageTypes(List<Map<String, dynamic>> seeds) {
    final typeBox = _db.get<ComponentType>();
    final componentBox = _db.get<Component>();
    final seedByName = {for (final s in seeds) _key(s["name"] as String): s};
    final categories = {
      for (final c in _db.get<Category>().getAll()) _key(c.name): c,
    };
    Map<String, ComponentType> types() => {
      for (final t in typeBox.getAll()) _key(t.name): t,
    };

    /// Loại theo tên, chưa có thì tạo từ seed.
    ComponentType ensure(String name) {
      final existing = types()[_key(name)];
      if (existing != null) return existing;
      final seed = seedByName[_key(name)];
      final used = {for (final t in typeBox.getAll()) ...t.keywords};
      final type = ComponentType(
        name: name,
        defaultIconSvg: seed?["defaultIconSvg"] as String? ?? "",
        keywords: _mergeKeywords(
          const [],
          (seed?["keywords"] as List? ?? const []).cast<String>(),
          used,
        ),
        attributeTemplate: (seed?["attributeTemplate"] as List? ?? const [])
            .cast<String>(),
      );
      type.category.target =
          categories[_key(seed?["categoryName"] as String? ?? "")];
      typeBox.put(type);
      return type;
    }

    List<Component> componentsOf(ComponentType type) =>
        componentBox.query(Component_.type.equals(type.id)).findAndClose();

    for (final MapEntry(key: oldName, value: newName)
        in packageTypeMerges.entries) {
      final old = types()[_key(oldName)];
      if (old == null) continue;

      if (newName == null) {
        // Phân loại lại theo tên linh kiện, bỏ qua chính các loại cũ
        final candidates = typeBox
            .getAll()
            .where(
              (t) =>
                  !packageTypeMerges.keys.any((k) => _key(k) == _key(t.name)),
            )
            .toList();
        final moved = componentsOf(old);
        for (final c in moved) {
          final match =
              KeywordMatcher.bestMatch(c.name, candidates, (t) => t.keywords) ??
              ensure(fallbackIcType);
          c.type.targetId = match.id;
        }
        componentBox.putMany(moved);
        typeBox.remove(old.id);
        continue;
      }

      final target = types()[_key(newName)];
      if (target == null) {
        // Chưa có loại mới => đổi tên loại cũ (giữ icon, từ khoá đã sửa)
        old.name = newName;
        typeBox.put(old);
        continue;
      }
      final moved = componentsOf(old);
      for (final c in moved) {
        c.type.targetId = target.id;
      }
      componentBox.putMany(moved);
      target.keywords = KeywordMatcher.normalizeAll([
        ...target.keywords,
        ...old.keywords,
      ]);
      if (target.attributeTemplate.isEmpty) {
        target.attributeTemplate = [...old.attributeTemplate];
      }
      typeBox.remove(old.id);
      typeBox.put(target);
    }

    for (final name in v3NewTypes) {
      ensure(name);
    }
  }

  Map<String, Category> _seedCategories(List<Map<String, dynamic>> seeds) {
    final box = _db.get<Category>();
    final existing = {for (final c in box.getAll()) _key(c.name): c};
    final usedKeywords = {for (final c in existing.values) ...c.keywords};

    for (final seed in seeds) {
      final name = seed["name"] as String;
      final category =
          existing[_key(name)] ??
          Category(name: name, colorValue: seed["colorValue"] as int);

      if (category.description.isEmpty) {
        category.description = seed["description"] as String? ?? "";
      }
      if (category.iconSvg.isEmpty) {
        category.iconSvg = seed["iconSvg"] as String? ?? "";
      }
      category.keywords = _mergeKeywords(
        category.keywords,
        (seed["keywords"] as List).cast<String>(),
        usedKeywords,
      );

      box.put(category);
      existing[_key(name)] = category;
    }
    return existing;
  }

  void _seedTypes(
    List<Map<String, dynamic>> seeds,
    Map<String, Category> categoriesByName,
  ) {
    final box = _db.get<ComponentType>();
    final existing = {for (final t in box.getAll()) _key(t.name): t};
    final usedKeywords = {for (final t in existing.values) ...t.keywords};

    for (final seed in seeds) {
      final name = seed["name"] as String;
      final type = existing[_key(name)] ?? ComponentType(name: name);

      if (type.defaultIconSvg.isEmpty) {
        type.defaultIconSvg = seed["defaultIconSvg"] as String? ?? "";
      }
      if (type.category.targetId == 0) {
        type.category.target =
            categoriesByName[_key(seed["categoryName"] as String? ?? "")];
      }
      type.keywords = _mergeKeywords(
        type.keywords,
        (seed["keywords"] as List).cast<String>(),
        usedKeywords,
      );

      box.put(type);
      existing[_key(name)] = type;
    }
  }

  /// Thêm keyword seed vào danh sách hiện có, bỏ qua keyword đã thuộc bản ghi khác.
  List<String> _mergeKeywords(
    List<String> current,
    List<String> seeds,
    Set<String> usedKeywords,
  ) {
    final merged = KeywordMatcher.normalizeAll(current);
    for (final keyword in KeywordMatcher.normalizeAll(seeds)) {
      if (merged.contains(keyword) || usedKeywords.contains(keyword)) continue;
      merged.add(keyword);
      usedKeywords.add(keyword);
    }
    return merged;
  }

  String _key(String name) => name.trim().toLowerCase();
}
