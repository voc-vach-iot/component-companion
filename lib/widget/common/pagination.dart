import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Phân trang: số trang bấm được (rút gọn bằng "…"), về đầu / cuối và ô
/// nhập trang khi có nhiều trang.
class AppPagination extends HookWidget {
  /// Trang hiện tại (bắt đầu từ 0).
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChange;

  /// Số trang hiển thị mỗi bên trang hiện tại.
  final int siblings;

  const AppPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChange,
    this.siblings = 1,
  });

  /// Danh sách trang cần hiện (0-based), null = dấu "…".
  static List<int?> visiblePages(int current, int total, int siblings) {
    if (total <= 0) return const [];
    final pages = <int>{
      0,
      total - 1,
      for (var i = current - siblings; i <= current + siblings; i++)
        if (i >= 0 && i < total) i,
    }.toList()..sort();
    final result = <int?>[];
    for (var i = 0; i < pages.length; i++) {
      if (i > 0) {
        final gap = pages[i] - pages[i - 1];
        // Thiếu đúng 1 trang thì hiện luôn trang đó thay vì "…"
        if (gap == 2) result.add(pages[i] - 1);
        if (gap > 2) result.add(null);
      }
      result.add(pages[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final jumpCtrl = useTextEditingController();
    if (totalPages <= 1) return const SizedBox.shrink();

    void go(int page) {
      final target = page.clamp(0, totalPages - 1);
      if (target != currentPage) onPageChange(target);
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        _NavButton(
          icon: Icons.first_page,
          tooltip: "Trang đầu",
          onPressed: currentPage > 0 ? () => go(0) : null,
        ),
        _NavButton(
          icon: Icons.chevron_left,
          tooltip: "Trang trước",
          onPressed: currentPage > 0 ? () => go(currentPage - 1) : null,
        ),
        for (final page in visiblePages(currentPage, totalPages, siblings))
          page == null
              ? const SizedBox(
                  width: 24,
                  child: Text(
                    "…",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : _PageButton(
                  page: page,
                  selected: page == currentPage,
                  onPressed: () => go(page),
                ),
        _NavButton(
          icon: Icons.chevron_right,
          tooltip: "Trang sau",
          onPressed: currentPage < totalPages - 1
              ? () => go(currentPage + 1)
              : null,
        ),
        _NavButton(
          icon: Icons.last_page,
          tooltip: "Trang cuối",
          onPressed: currentPage < totalPages - 1
              ? () => go(totalPages - 1)
              : null,
        ),
        if (totalPages > 7)
          SizedBox(
            width: 64,
            height: 34,
            child: TextField(
              controller: jumpCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "Trang",
                hintStyle: const TextStyle(fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (value) {
                final page = int.tryParse(value);
                if (page != null) go(page - 1);
                jumpCtrl.clear();
              },
            ),
          ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  final int page;
  final bool selected;
  final VoidCallback onPressed;

  const _PageButton({
    required this.page,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onPressed,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 34),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        // widthFactor: 1 => rộng theo nội dung, không giãn hết hàng
        child: Center(
          widthFactor: 1,
          child: Text(
            "${page + 1}",
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: AppColors.textMain,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
            color: disabled ? Colors.grey.shade100 : Colors.white,
          ),
          child: Icon(
            icon,
            size: 18,
            color: disabled ? AppColors.textDisabled : AppColors.textMain,
          ),
        ),
      ),
    );
  }
}
