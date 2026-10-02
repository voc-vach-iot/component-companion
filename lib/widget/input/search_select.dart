import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/highlight_text.dart';
import 'package:component_companion/widget/input/search_options_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Ô chọn 1 phần tử từ danh sách, có tìm kiếm (dùng chung tuỳ chọn tìm kiếm
/// của app: bỏ dấu, hoa thường, cách khớp) và tô sáng phần khớp.
///
/// Thay cho Dropdown khi danh sách dài (danh mục, loại, linh kiện, ...).
class AppSearchSelect<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String Function(T item) labelOf;
  final Widget Function(T item)? leadingOf;
  final String? Function(T item)? subtitleOf;

  /// Nếu khác null: thêm lựa chọn "không chọn" (trả về null) ở đầu danh sách.
  final String? noneLabel;
  final String hintText;

  const AppSearchSelect({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.leadingOf,
    this.subtitleOf,
    this.noneLabel,
    this.hintText = "Chọn...",
  });

  @override
  Widget build(BuildContext context) {
    const borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.border, width: 2.0),
    );
    final selected = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        SearchPopupAnchor(
          popupBuilder: (close) => SearchSelectPopup<T>(
            items: items,
            selected: {?selected},
            labelOf: labelOf,
            leadingOf: leadingOf,
            subtitleOf: subtitleOf,
            noneLabel: noneLabel,
            onTap: (item) {
              close();
              onChanged(item);
            },
            onClose: close,
          ),
          builder: (context, isOpen, toggle) => InkWell(
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(12),
            onTap: toggle,
            child: InputDecorator(
              isFocused: isOpen,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                enabledBorder: borderStyle,
                focusedBorder: borderStyle.copyWith(
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2.0,
                  ),
                ),
                border: borderStyle,
                suffixIcon: Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_outlined
                      : Icons.keyboard_arrow_down_outlined,
                ),
              ),
              child: Row(
                children: [
                  if (selected != null && leadingOf != null) ...[
                    leadingOf!(selected),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      selected != null
                          ? labelOf(selected)
                          : (noneLabel ?? hintText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: selected != null
                            ? AppColors.textMain
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nút lọc chọn NHIỀU giá trị (VD lọc theo danh mục), có tìm kiếm.
class AppFilterSelect<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<T> items;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final String Function(T item) labelOf;
  final Widget Function(T item)? leadingOf;
  final String? Function(T item)? subtitleOf;
  final double popupWidth;

  const AppFilterSelect({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.leadingOf,
    this.subtitleOf,
    this.popupWidth = 340,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected.isNotEmpty;
    final summary = !active
        ? label
        : selected.length == 1
        ? labelOf(selected.first)
        : "$label (${selected.length})";

    return SearchPopupAnchor(
      popupWidth: popupWidth,
      popupBuilder: (close) => SearchSelectPopup<T>(
        items: items,
        selected: selected,
        labelOf: labelOf,
        leadingOf: leadingOf,
        subtitleOf: subtitleOf,
        multiSelect: true,
        onTap: (item) {
          if (item == null) return;
          final next = {...selected};
          next.contains(item) ? next.remove(item) : next.add(item);
          onChanged(next);
        },
        onClear: active ? () => onChanged(const {}) : null,
        onClose: close,
      ),
      builder: (context, isOpen, toggle) => FilterChip(
        avatar: Icon(
          icon,
          size: 16,
          color: active ? AppColors.textMain : AppColors.textMuted,
        ),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(summary, overflow: TextOverflow.ellipsis)),
              Icon(
                isOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
              ),
            ],
          ),
        ),
        showCheckmark: false,
        selected: active,
        selectedColor: AppColors.primary.withValues(alpha: 0.35),
        backgroundColor: AppColors.background,
        side: BorderSide(color: active ? AppColors.primary : AppColors.border),
        onSelected: (_) => toggle(),
      ),
    );
  }
}

/// Neo 1 popup ngay dưới (hoặc trên nếu thiếu chỗ) widget [builder].
/// Bấm ra ngoài popup để đóng.
class SearchPopupAnchor extends HookWidget {
  final Widget Function(BuildContext context, bool isOpen, VoidCallback toggle)
  builder;
  final Widget Function(VoidCallback close) popupBuilder;

  /// null = rộng bằng widget neo.
  final double? popupWidth;

  const SearchPopupAnchor({
    super.key,
    required this.builder,
    required this.popupBuilder,
    this.popupWidth,
  });

  @override
  Widget build(BuildContext context) {
    final portal = useMemoized(OverlayPortalController.new);
    final link = useMemoized(LayerLink.new);
    final tapGroup = useMemoized(Object.new);
    final anchorKey = useMemoized(GlobalKey.new);
    final openAbove = useState(false);
    final width = useState(0.0);
    final isOpen = useState(false);

    void close() {
      if (!portal.isShowing) return;
      portal.hide();
      isOpen.value = false;
    }

    void open() {
      final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final top = box.localToGlobal(Offset.zero).dy;
      final screenHeight = MediaQuery.sizeOf(context).height;
      final spaceBelow = screenHeight - top - box.size.height;
      width.value = popupWidth ?? box.size.width;
      openAbove.value =
          spaceBelow < SearchSelectPopup.maxHeight + 16 && top > spaceBelow;
      portal.show();
      isOpen.value = true;
    }

    return TapRegion(
      groupId: tapGroup,
      child: CompositedTransformTarget(
        link: link,
        child: OverlayPortal(
          controller: portal,
          overlayChildBuilder: (_) => Positioned(
            width: width.value,
            child: CompositedTransformFollower(
              link: link,
              showWhenUnlinked: false,
              targetAnchor: openAbove.value
                  ? Alignment.topLeft
                  : Alignment.bottomLeft,
              followerAnchor: openAbove.value
                  ? Alignment.bottomLeft
                  : Alignment.topLeft,
              offset: Offset(0, openAbove.value ? -4 : 4),
              child: TapRegion(
                groupId: tapGroup,
                onTapOutside: (_) {
                  // Đang mở menu tuỳ chọn tìm kiếm (route khác đè lên) => không đóng
                  if (ModalRoute.of(context)?.isCurrent == false) return;
                  close();
                },
                child: popupBuilder(close),
              ),
            ),
          ),
          child: KeyedSubtree(
            key: anchorKey,
            child: builder(
              context,
              isOpen.value,
              () => portal.isShowing ? close() : open(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Danh sách có ô tìm kiếm trong popup. [multiSelect] = hiện checkbox, bấm
/// chọn không đóng popup.
class SearchSelectPopup<T> extends HookConsumerWidget {
  static const double maxHeight = 360;
  static const double _itemExtent = 44;
  static const double _itemExtentWithSubtitle = 56;

  final List<T> items;
  final Set<T> selected;
  final String Function(T item) labelOf;
  final Widget Function(T item)? leadingOf;
  final String? Function(T item)? subtitleOf;
  final String? noneLabel;
  final bool multiSelect;

  /// Bấm vào 1 dòng (null = dòng "không chọn").
  final ValueChanged<T?> onTap;
  final VoidCallback? onClear;
  final VoidCallback onClose;

  const SearchSelectPopup({
    super.key,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onTap,
    required this.onClose,
    this.leadingOf,
    this.subtitleOf,
    this.noneLabel,
    this.multiSelect = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryController = useTextEditingController();
    final query = useValueListenable(queryController).text;
    final options = ref.watch(searchOptionsProvider);
    final search = useMemoized(() => TextSearch(query, options), [
      query,
      options,
    ]);
    final scrollController = useScrollController();
    final itemExtent = subtitleOf == null
        ? _itemExtent
        : _itemExtentWithSubtitle;

    // null = lựa chọn "không chọn"
    final entries = useMemoized<List<T?>>(
      () => [
        if (noneLabel != null && search.isEmpty) null,
        ...search.rank<T>(items, labelOf),
      ],
      [search, items],
    );

    final highlighted = useState(0);
    useEffect(() {
      // Mở lần đầu: trỏ vào phần tử đang chọn; khi gõ tìm: về phần tử đầu
      final index = query.isEmpty && !multiSelect
          ? entries.indexOf(selected.firstOrNull)
          : 0;
      highlighted.value = index < 0 ? 0 : index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) return;
        final position = scrollController.position;
        scrollController.jumpTo(
          (highlighted.value * itemExtent - position.viewportDimension / 3)
              .clamp(0.0, position.maxScrollExtent),
        );
      });
      return null;
    }, [entries]);

    void moveHighlight(int delta) {
      if (entries.isEmpty) return;
      final next = (highlighted.value + delta).clamp(0, entries.length - 1);
      highlighted.value = next;
      final position = scrollController.position;
      final top = next * itemExtent;
      if (top < position.pixels) {
        scrollController.jumpTo(top);
      } else if (top + itemExtent >
          position.pixels + position.viewportDimension) {
        scrollController.jumpTo(top + itemExtent - position.viewportDimension);
      }
    }

    KeyEventResult onKey(FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
          moveHighlight(1);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          moveHighlight(-1);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
          if (entries.isNotEmpty) onTap(entries[highlighted.value]);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.escape:
          onClose();
          return KeyEventResult.handled;
        default:
          return KeyEventResult.ignored;
      }
    }

    return Material(
      elevation: 8,
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
              child: Focus(
                onKeyEvent: onKey,
                child: TextField(
                  controller: queryController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "Tìm kiếm...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: const SearchOptionsButton(),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ),
            if (multiSelect && onClear != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onClear,
                  child: Text("Bỏ chọn (${selected.length})"),
                ),
              ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Không tìm thấy kết quả",
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  // Co lại theo số kết quả (tối đa maxHeight)
                  shrinkWrap: true,
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 6),
                  itemExtent: itemExtent,
                  itemCount: entries.length,
                  itemBuilder: (context, index) =>
                      _entry(entries[index], index, highlighted, search),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _entry(
    T? item,
    int index,
    ValueNotifier<int> highlighted,
    TextSearch search,
  ) {
    final isSelected = item != null && selected.contains(item);
    final subtitle = item == null ? null : subtitleOf?.call(item);

    return Material(
      color: index == highlighted.value
          ? AppColors.primary.withValues(alpha: 0.18)
          : Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () => onTap(item),
        onHover: (hovering) {
          if (hovering) highlighted.value = index;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (multiSelect) ...[
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color: isSelected ? AppColors.info : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
              ],
              if (item != null && leadingOf != null) ...[
                leadingOf!(item),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    item == null
                        ? Text(
                            noneLabel!,
                            style: const TextStyle(color: AppColors.textMuted),
                          )
                        : HighlightText(
                            labelOf(item),
                            search: search,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected && !multiSelect
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected && !multiSelect)
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.info,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
