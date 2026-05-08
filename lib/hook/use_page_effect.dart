import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/search_params/paging_search_params.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void usePagingEffect<T>({
  required AsyncValue<PageResult<T>> pageResultAsync,
  required ValueNotifier<PagingSearchParams> searchParamsNotifier,
}) {
  final previousTotal = useRef<int?>(null);

  useEffect(() {
    pageResultAsync.whenData((data) {
      final int size = searchParamsNotifier.value.size;
      final int currentTotal = data.totalItems;

      if (previousTotal.value == null) {
        previousTotal.value = currentTotal;
        return;
      }

      final int lastTotal = previousTotal.value!;

      // Dùng WidgetsBinding để tách việc update State ra khỏi quá trình Build
      // giúp tránh lỗi "Deactivated widget" hoặc "Build scheduled during build"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 1. Nếu THÊM MỚI: Tính trang cuối cùng dựa trên totalItems mới
        if (currentTotal > lastTotal) {
          final targetPage = ((currentTotal - 1) / size)
              .floor()
              .clamp(0, double.infinity)
              .toInt();

          // Nếu trang chứa item mới khác trang hiện tại -> Nhảy tới đó
          if (targetPage != searchParamsNotifier.value.page) {
            searchParamsNotifier.value = (searchParamsNotifier.value as dynamic)
                .copyWith(page: targetPage);
          }
        }
        // 2. Nếu XÓA: Dùng logic cũ của bạn nhưng chạy trong callback an toàn
        else if (currentTotal < lastTotal) {
          final maxPage = ((currentTotal - 1) / size)
              .floor()
              .clamp(0, double.infinity)
              .toInt();

          if (searchParamsNotifier.value.page > maxPage) {
            searchParamsNotifier.value = (searchParamsNotifier.value as dynamic)
                .copyWith(page: maxPage);
          }
        }
      });

      previousTotal.value = currentTotal;
    });
    return null;
  }, [pageResultAsync.asData?.value.totalItems]);
}
