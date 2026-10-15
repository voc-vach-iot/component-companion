import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/icon_repository.dart';
import 'package:component_companion/notifier/icon_notifier.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/icon/icon_action.dart';
import 'package:component_companion/widget/icon/icon_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Thư viện icon: nhập / xuất bộ icon CSV, dùng để chọn nhanh icon cho danh
/// mục, loại và linh kiện.
class IconLibraryPage extends HookConsumerWidget {
  const IconLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = useState("");
    final pack = useState<String?>(null);
    final searchOptions = ref.watch(searchOptionsProvider);
    final search = useMemoized(() => TextSearch(name.value, searchOptions), [
      name.value,
      searchOptions,
    ]);
    final iconsAsync = ref.watch(watchIconsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader(
            title: "Thư viện icon".toUpperCase(),
            onSearch: (value) => name.value = value,
            onAddPressed: () => IconAction.showAdd(
              context,
              initialPack: pack.value ?? IconRepository.userPack,
            ),
            trailing: Row(
              children: [
                const SizedBox(width: 8),
                AppButton(
                  label: "Nhập CSV",
                  icon: Icons.file_upload_outlined,
                  variant: ButtonVariant.secondary,
                  onPressed: () => IconAction.importCsv(context),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: "File mẫu",
                  icon: Icons.description_outlined,
                  variant: ButtonVariant.secondary,
                  onPressed: () => IconAction.saveTemplate(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Mỗi file CSV là 1 bộ icon (cột: name, svg, keywords, pack). Ở ô Icon "
            "của danh mục / loại / linh kiện bấm \"Thư viện\" để chọn, hoặc "
            "\"Lưu vào thư viện\" để giữ lại SVG vừa dán.",
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: iconsAsync.when(
              loading: () => const AppLoadingView(),
              error: (e, _) => AppErrorView(message: "Lỗi tải icon: $e"),
              data: (icons) {
                final packs = countByPack(icons);
                // Bộ đang chọn vừa bị xoá => về "Tất cả"
                final selectedPack = packs.containsKey(pack.value)
                    ? pack.value
                    : null;
                final shown = filterIcons(
                  icons,
                  search: search,
                  pack: selectedPack,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: IconPackChips(
                            packs: packs,
                            total: icons.length,
                            selected: selectedPack,
                            onSelected: (p) => pack.value = p,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: shown.isEmpty
                              ? null
                              : () => IconAction.exportCsv(
                                  context,
                                  shown,
                                  name: selectedPack ?? "icons",
                                ),
                          icon: const Icon(Icons.file_download_outlined),
                          label: Text("Xuất CSV (${shown.length})"),
                        ),
                        if (selectedPack != null)
                          TextButton.icon(
                            onPressed: () => IconAction.showDeletePack(
                              context,
                              selectedPack,
                              packs[selectedPack]!,
                            ),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            label: const Text(
                              "Xoá bộ",
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: icons.isEmpty
                          ? const Center(
                              child: Text(
                                "Chưa có icon nào. Bấm \"Nhập CSV\" để thêm bộ icon.",
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            )
                          : IconGrid(
                              icons: shown,
                              search: search,
                              tileSize: 120,
                              onTap: (icon) =>
                                  IconAction.showEdit(context, icon),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
