import 'dart:async';
import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class AppSearchBar extends HookWidget {
  final String hintText;
  final Function(String) onSearch;
  final double maxWidth;
  final Duration debounceDuration;

  const AppSearchBar({
    super.key,
    required this.onSearch,
    this.hintText = "Tìm kiếm...",
    this.maxWidth = double.infinity,
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();
    final text = useListenable(controller).text;

    // useRef để giữ Timer tồn tại qua các lần rebuild
    final debounceTimer = useRef<Timer?>(null);

    // Logic Debounce: chỉ gọi onSearch sau khi người dùng ngừng gõ 500ms
    useEffect(() {
      return () => debounceTimer.value?.cancel();
    }, []);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SearchBar(
        controller: controller,
        constraints: const BoxConstraints(minWidth: 200.0, minHeight: 48.0),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: const WidgetStatePropertyAll(AppColors.background),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.primary.withValues(alpha: 0.05);
          }
          if (states.contains(WidgetState.focused)) {
            return AppColors.primary.withValues(alpha: 0.1);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith<BorderSide>((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(color: AppColors.primary, width: 2.0);
          }
          return const BorderSide(color: AppColors.primaryLight, width: 1.0);
        }),
        hintText: hintText,
        hintStyle: const WidgetStatePropertyAll(
          TextStyle(color: AppColors.textMuted),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        // Logic khi text thay đổi
        onChanged: (val) {
          debounceTimer.value?.cancel();
          debounceTimer.value = Timer(debounceDuration, () {
            onSearch(val);
          });
        },
        leading: const Icon(Icons.search, color: AppColors.primary, size: 22),
        trailing: [
          if (text.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.close,
                size: 20,
                color: AppColors.textMuted,
              ),
              onPressed: () {
                controller.clear();
                debounceTimer.value?.cancel();
                onSearch('');
              },
            ),
        ],
      ),
    );
  }
}
