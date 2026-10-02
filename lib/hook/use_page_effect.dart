import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/search_params/paging_search_params.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Phần tử cần focus trong danh sách. [token] tăng mỗi lần focus để kích hoạt
/// lại hiệu ứng cuộn/nháy kể cả khi focus cùng 1 id.
typedef FocusTarget = ({int id, int token});

/// Kết quả phân trang đã xử lý cho UI.
class PagedState<T> {
  /// Dữ liệu để render: khi đang tải trang/tham số mới vẫn giữ dữ liệu cũ để
  /// danh sách không bị thay bằng loading (gây nhảy về đầu).
  final AsyncValue<PageResult<T>> result;

  /// Phần tử vừa thêm/nhân bản cần cuộn tới.
  final FocusTarget? focus;

  /// Yêu cầu focus vào [id]: repository sẽ trả về trang chứa nó.
  final void Function(int id) focusOn;

  const PagedState(this.result, this.focus, this.focusOn);
}

PagedState<T> usePagingEffect<T>({
  required AsyncValue<PageResult<T>> pageResultAsync,
  required ValueNotifier<PagingSearchParams> searchParamsNotifier,
}) {
  final lastData = useRef<PageResult<T>?>(null);
  final focus = useState<FocusTarget?>(null);
  final context = useContext();

  final current = pageResultAsync.asData?.value;
  if (current != null) lastData.value = current;

  useEffect(() {
    final data = current;
    if (data == null) return null;
    final params = searchParamsNotifier.value;

    // Dùng WidgetsBinding để tách việc update State ra khỏi quá trình Build
    // giúp tránh lỗi "Deactivated widget" hoặc "Build scheduled during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. Đã có trang chứa phần tử cần focus => đồng bộ số trang, bỏ focusId
      // khỏi params để các lần chuyển trang sau không bị kéo về đây
      if (params.focusId != null) {
        final target = (
          id: params.focusId!,
          token: (focus.value?.token ?? 0) + 1,
        );
        focus.value = target;
        // Hết hiệu ứng thì bỏ focus để không nháy lại khi danh sách thay đổi
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (context.mounted && focus.value == target) focus.value = null;
        });
        searchParamsNotifier.value = (params as dynamic).copyWith(
          page: data.currentPage,
          focusId: null,
        );
        return;
      }

      // 2. Nếu XÓA làm trang hiện tại trống: lùi về trang cuối còn dữ liệu
      final maxPage = ((data.totalItems - 1) / params.size)
          .floor()
          .clamp(0, double.infinity)
          .toInt();
      if (params.page > maxPage) {
        searchParamsNotifier.value = (params as dynamic).copyWith(
          page: maxPage,
        );
      }
    });

    return null;
  }, [current]);

  final result = current == null && lastData.value != null
      ? AsyncData<PageResult<T>>(lastData.value as PageResult<T>)
      : pageResultAsync;

  return PagedState(result, focus.value, (id) {
    searchParamsNotifier.value = (searchParamsNotifier.value as dynamic)
        .copyWith(focusId: id);
  });
}

/// Giữ dữ liệu cũ khi provider đang tải lại (đổi tham số) để tránh nháy loading.
AsyncValue<T> useKeepPreviousData<T>(AsyncValue<T> value) {
  final last = useRef<T?>(null);
  if (value.hasValue) last.value = value.value;
  if (!value.hasValue && !value.hasError && last.value != null) {
    return AsyncData<T>(last.value as T);
  }
  return value;
}
