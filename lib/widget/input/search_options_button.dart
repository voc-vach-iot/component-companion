import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Nút mở menu tuỳ chọn tìm kiếm (dùng chung toàn app).
class SearchOptionsButton extends ConsumerWidget {
  const SearchOptionsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(searchOptionsProvider);
    final notifier = ref.read(searchOptionsProvider.notifier);
    final isDefault = options == const SearchOptions();

    PopupMenuItem<VoidCallback> radio({
      required bool selected,
      required String label,
      required String description,
      required SearchOptions next,
    }) {
      return PopupMenuItem<VoidCallback>(
        value: () => notifier.update(next),
        height: 40,
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.info : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Tooltip(
                message: description,
                waitDuration: const Duration(milliseconds: 400),
                child: Text(label),
              ),
            ),
          ],
        ),
      );
    }

    PopupMenuItem<VoidCallback> header(String text) => PopupMenuItem(
      enabled: false,
      height: 32,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );

    return PopupMenuButton<VoidCallback>(
      tooltip:
          "Tuỳ chọn tìm kiếm: ${options.matchMode.label} · "
          "Hoa thường: ${options.caseMode.label}"
          "${options.normalize ? " · Bỏ dấu" : ""}",
      color: AppColors.background,
      onSelected: (action) => action(),
      icon: Badge(
        isLabelVisible: !isDefault,
        smallSize: 7,
        backgroundColor: AppColors.info,
        child: const Icon(Icons.tune_rounded, size: 20),
      ),
      itemBuilder: (context) => [
        header("CÁCH KHỚP"),
        for (final mode in SearchMatchMode.values)
          radio(
            selected: options.matchMode == mode,
            label: mode.label,
            description: mode.description,
            next: options.copyWith(matchMode: mode),
          ),
        const PopupMenuDivider(),
        header("HOA / THƯỜNG"),
        for (final mode in SearchCaseMode.values)
          radio(
            selected: options.caseMode == mode,
            label: mode.label,
            description: mode.description,
            next: options.copyWith(caseMode: mode),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<VoidCallback>(
          value: () =>
              notifier.update(options.copyWith(normalize: !options.normalize)),
          height: 40,
          child: Row(
            children: [
              Icon(
                options.normalize
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: options.normalize ? AppColors.info : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              const Text("Bỏ dấu (tu hoa ≈ Tụ hóa, uF ≈ µF)"),
            ],
          ),
        ),
        if (!isDefault) ...[
          const PopupMenuDivider(),
          PopupMenuItem<VoidCallback>(
            value: () => notifier.update(const SearchOptions()),
            height: 40,
            child: const Text("Khôi phục mặc định"),
          ),
        ],
      ],
    );
  }
}
