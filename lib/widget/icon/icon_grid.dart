import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/highlight_text.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:flutter/material.dart';

/// Lọc icon theo bộ + chuỗi tìm (khớp tên, từ khoá hoặc tên bộ).
List<IconAsset> filterIcons(
  List<IconAsset> icons, {
  required TextSearch search,
  String? pack,
}) {
  final inPack = pack == null ? icons : icons.where((i) => i.pack == pack);
  return search.rank(
    inPack,
    (i) => [i.name, ...i.keywords, i.pack].join(" · "),
  );
}

/// Số icon theo từng bộ (giữ thứ tự xuất hiện).
Map<String, int> countByPack(List<IconAsset> icons) {
  final counts = <String, int>{};
  for (final i in icons) {
    counts.update(i.pack, (c) => c + 1, ifAbsent: () => 1);
  }
  return counts;
}

/// Hàng chip chọn bộ icon ("Tất cả" + từng bộ).
class IconPackChips extends StatelessWidget {
  final Map<String, int> packs;
  final int total;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const IconPackChips({
    super.key,
    required this.packs,
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      ChoiceChip(
        label: Text("Tất cả ($total)"),
        visualDensity: VisualDensity.compact,
        selected: selected == null,
        onSelected: (_) => onSelected(null),
      ),
      for (final MapEntry(key: pack, value: count) in packs.entries)
        ChoiceChip(
          label: Text("${pack.isEmpty ? "(không tên)" : pack} ($count)"),
          visualDensity: VisualDensity.compact,
          selected: selected == pack,
          onSelected: (_) => onSelected(pack),
        ),
    ],
  );
}

class IconGrid extends StatelessWidget {
  final List<IconAsset> icons;
  final TextSearch? search;
  final ValueChanged<IconAsset> onTap;

  /// Icon đang được chọn (so theo SVG), để tô viền.
  final String? selectedSvg;
  final double tileSize;

  const IconGrid({
    super.key,
    required this.icons,
    required this.onTap,
    this.search,
    this.selectedSvg,
    this.tileSize = 104,
  });

  @override
  Widget build(BuildContext context) {
    if (icons.isEmpty) {
      return const Center(
        child: Text(
          "Không có icon nào",
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: tileSize,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final icon = icons[index];
        final isSelected = selectedSvg != null && selectedSvg == icon.svg;
        return Tooltip(
          message: [
            icon.name,
            if (icon.pack.isNotEmpty) "Bộ: ${icon.pack}",
            if (icon.keywords.isNotEmpty) icon.keywords.join(", "),
          ].join("\n"),
          waitDuration: const Duration(milliseconds: 500),
          child: InkWell(
            onTap: () => onTap(icon),
            borderRadius: BorderRadius.circular(10),
            mouseCursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(child: AppSvgIcon(svg: icon.svg, size: 32)),
                  ),
                  const SizedBox(height: 6),
                  HighlightText(
                    icon.name,
                    search: search,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
