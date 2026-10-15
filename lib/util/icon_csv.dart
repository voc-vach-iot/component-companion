import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:component_companion/widget/common/svg_icon.dart';

/// Đọc / ghi bộ icon dạng CSV.
///
/// Cột (dòng tiêu đề không bắt buộc, không phân biệt hoa thường):
/// - `name` / `tên`: tên icon (bắt buộc)
/// - `svg`: mã SVG (bắt buộc)
/// - `keywords` / `từ khoá` / `tags`: từ khoá, cách nhau bởi `;` hoặc `|`
/// - `pack` / `bộ`: tên bộ icon (trống => tên file đang nhập)
///
/// Không có dòng tiêu đề => thứ tự cột: name, svg, keywords, pack.
class IconCsv {
  IconCsv._();

  static const header = ["name", "svg", "keywords", "pack"];

  static const _aliases = {
    "name": ["name", "tên", "ten", "title", "label"],
    "svg": ["svg", "icon", "code", "mã svg"],
    "keywords": [
      "keywords",
      "keyword",
      "từ khoá",
      "từ khóa",
      "tu khoa",
      "tags",
    ],
    "pack": ["pack", "bộ", "bo", "set", "group", "nhóm"],
  };

  static String encode(Iterable<IconAsset> icons) => Csv.encode([
    header,
    for (final i in icons) [i.name, i.svg, i.keywords.join("; "), i.pack],
  ]);

  /// Trả về icon hợp lệ và số dòng bị bỏ qua (thiếu tên / SVG không hợp lệ).
  static ({List<IconAsset> icons, int skipped}) decode(
    String text, {
    required String defaultPack,
  }) {
    final rows = Csv.decode(text.replaceFirst("﻿", ""));
    if (rows.isEmpty) return (icons: const [], skipped: 0);

    // Dòng đầu có ô nào là SVG => không phải tiêu đề
    final first = rows.first;
    final hasHeader = !first.any(AppSvgIcon.looksLikeSvg);
    final columns = <String, int>{};
    if (hasHeader) {
      final names = first.map((c) => c.trim().toLowerCase()).toList();
      for (final MapEntry(key: field, value: aliases) in _aliases.entries) {
        final index = names.indexWhere(aliases.contains);
        if (index >= 0) columns[field] = index;
      }
    }
    if (!columns.containsKey("name") || !columns.containsKey("svg")) {
      columns
        ..clear()
        ..addAll({for (final (i, field) in header.indexed) field: i});
    }

    String cell(List<String> row, String field) {
      final index = columns[field];
      return index == null || index >= row.length ? "" : row[index].trim();
    }

    final icons = <IconAsset>[];
    var skipped = 0;
    for (final row in rows.skip(hasHeader ? 1 : 0)) {
      final name = cell(row, "name");
      final svg = cell(row, "svg");
      if (name.isEmpty || !AppSvgIcon.looksLikeSvg(svg)) {
        skipped++;
        continue;
      }
      final pack = cell(row, "pack");
      icons.add(
        IconAsset(
          name: name,
          svg: svg,
          pack: pack.isEmpty ? defaultPack : pack,
          keywords: splitKeywords(cell(row, "keywords")),
        ),
      );
    }
    return (icons: icons, skipped: skipped);
  }

  static List<String> splitKeywords(String text) =>
      KeywordMatcher.normalizeAll(text.split(RegExp(r'[;|,\n]')));
}
