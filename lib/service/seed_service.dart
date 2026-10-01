import 'dart:convert';

import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/app_setting.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// Nạp dữ liệu mặc định (danh mục, loại linh kiện) từ `assets/seed/`.
///
/// Mỗi phiên bản seed chỉ chạy 1 lần (lưu trong [AppSetting]). Dữ liệu được
/// gộp theo tên: bản ghi đã tồn tại chỉ được bổ sung các trường còn trống,
/// không ghi đè chỉnh sửa của người dùng.
class SeedService {
  /// Tăng số này khi cập nhật file seed để người dùng cũ nhận dữ liệu mới.
  static const int seedVersion = 1;
  static const String _seedVersionKey = "seed_version";

  final _db = ObjectboxService.instance;

  Future<void> run() async {
    final settingBox = _db.get<AppSetting>();
    final current = settingBox
        .query(AppSetting_.key.equals(_seedVersionKey))
        .findFirstAndClose();
    if ((int.tryParse(current?.value ?? "") ?? 0) >= seedVersion) return;

    final categoriesJson = await rootBundle.loadString(
      "assets/seed/categories.json",
    );
    final typesJson = await rootBundle.loadString(
      "assets/seed/component_types.json",
    );

    _db.store.runInTransaction(TxMode.write, () {
      final categoriesByName = _seedCategories(
        (jsonDecode(categoriesJson) as List).cast<Map<String, dynamic>>(),
      );
      _seedTypes(
        (jsonDecode(typesJson) as List).cast<Map<String, dynamic>>(),
        categoriesByName,
      );
      settingBox.put(
        AppSetting(key: _seedVersionKey, value: seedVersion.toString()),
      );
    });
    debugPrint("🌱 Đã nạp dữ liệu seed phiên bản $seedVersion");
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
