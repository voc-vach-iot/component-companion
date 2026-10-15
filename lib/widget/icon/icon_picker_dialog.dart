import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/notifier/icon_notifier.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/icon/icon_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Chọn 1 icon trong thư viện, trả về mã SVG (null nếu huỷ).
Future<String?> showIconPicker(
  BuildContext context, {
  String? currentSvg,
  String initialQuery = "",
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      IconPickerDialog(currentSvg: currentSvg, initialQuery: initialQuery),
);

class IconPickerDialog extends HookConsumerWidget {
  final String? currentSvg;

  /// Gợi ý tìm sẵn (VD tên linh kiện / loại đang nhập).
  final String initialQuery;

  const IconPickerDialog({super.key, this.currentSvg, this.initialQuery = ""});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryCtrl = useTextEditingController(text: initialQuery);
    final query = useValueListenable(queryCtrl).text;
    final pack = useState<String?>(null);
    final searchOptions = ref.watch(searchOptionsProvider);
    final search = useMemoized(() => TextSearch(query, searchOptions), [
      query,
      searchOptions,
    ]);
    final iconsAsync = ref.watch(watchIconsProvider);

    return AppAlertDialog(
      title: "Chọn icon từ thư viện",
      size: AlertDialogSize.big,
      content: SizedBox(
        height: 520,
        child: iconsAsync.when(
          loading: () => const AppLoadingView(),
          error: (e, _) => AppErrorView(message: "Lỗi tải icon: $e"),
          data: (icons) {
            if (icons.isEmpty) {
              return const Center(
                child: Text(
                  "Thư viện icon trống. Nhập bộ icon (CSV) ở trang \"Thư viện icon\".",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            final shown = filterIcons(icons, search: search, pack: pack.value);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: queryCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: "Tìm theo tên / từ khoá (VD: tụ, diode, pin)",
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: queryCtrl.clear,
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                IconPackChips(
                  packs: countByPack(icons),
                  total: icons.length,
                  selected: pack.value,
                  onSelected: (p) => pack.value = p,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: IconGrid(
                    icons: shown,
                    search: search,
                    selectedSvg: currentSvg,
                    onTap: (icon) => Navigator.of(context).pop(icon.svg),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
