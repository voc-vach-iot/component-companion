import 'dart:math' as math;

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/hook/use_page_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class GenericGrid<T> extends HookWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final double maxWidth;
  final double widthHeightRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final ScrollController? scrollController;

  /// Phần tử cần cuộn tới + nháy sáng (VD: vừa thêm mới).
  final FocusTarget? focus;
  final int Function(T item)? idOf;

  static const _padding = EdgeInsets.only(top: 16, bottom: 16);

  const GenericGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.maxWidth = 250,
    this.widthHeightRatio = 1,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.scrollController,
    this.focus,
    this.idOf,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackController = useScrollController();
    final controller = scrollController ?? fallbackController;
    final crossAxisExtent = useRef<double>(0);

    final focusIndex = focus == null || idOf == null
        ? -1
        : items.indexWhere((item) => idOf!(item) == focus!.id);

    // Chỉ cuộn khi có yêu cầu focus MỚI (token đổi), không cuộn lại khi phần
    // tử đã focus tình cờ xuất hiện trên trang do xoá phần tử khác
    useEffect(() {
      if (focusIndex < 0) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.hasClients) return;
        _scrollToIndex(controller, crossAxisExtent.value, focusIndex);
      });
      return null;
    }, [focus?.token]);

    if (items.isEmpty) {
      return const Center(child: Text("Không có dữ liệu"));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        crossAxisExtent.value = constraints.maxWidth;
        return GridView.builder(
          padding: _padding,
          controller: controller,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxWidth,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: widthHeightRatio,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            Widget child = itemBuilder(context, item);
            if (index == focusIndex) {
              child = FocusFlash(key: ValueKey(focus!.token), child: child);
            }
            // Key theo id để state con (VD: danh sách tuỳ chọn) không bị
            // dùng nhầm cho phần tử khác khi danh sách bị dồn sau khi xoá
            return idOf == null
                ? child
                : KeyedSubtree(key: ValueKey(idOf!(item)), child: child);
          },
        );
      },
    );
  }

  /// Tính vị trí hàng theo đúng công thức của SliverGridDelegateWithMaxCrossAxisExtent
  /// (phần tử có thể chưa được build nên không dùng ensureVisible được).
  void _scrollToIndex(ScrollController controller, double width, int index) {
    final count = math.max(1, (width / (maxWidth + crossAxisSpacing)).ceil());
    final usable = math.max(0.0, width - crossAxisSpacing * (count - 1));
    final childHeight = usable / count / widthHeightRatio;
    final rowTop =
        _padding.top + (index ~/ count) * (childHeight + mainAxisSpacing);

    final position = controller.position;
    final target = rowTop - (position.viewportDimension - childHeight) / 2;
    controller.animateTo(
      target.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }
}

/// Viền sáng mờ dần để đánh dấu phần tử vừa thêm/nhân bản.
class FocusFlash extends HookWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const FocusFlash({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 2200),
    );
    useEffect(() {
      controller.forward();
      return null;
    }, const []);
    final t = useAnimation(
      CurvedAnimation(parent: controller, curve: const Interval(0.35, 1)),
    );

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 1 - t),
                  width: 3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
