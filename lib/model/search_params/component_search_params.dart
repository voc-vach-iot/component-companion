import 'package:component_companion/model/search_params/paging_search_params.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'component_search_params.mapper.dart';

/// Lọc theo tình trạng tồn kho.
@MappableEnum()
enum StockFilter {
  all("Tất cả"),
  inStock("Còn hàng"),
  low("Sắp hết"),
  out("Hết hàng"),
  untracked("Chưa nhập kho");

  final String label;
  const StockFilter(this.label);
}

/// Cách sắp xếp danh sách linh kiện.
@MappableEnum()
enum ComponentSort {
  added("Thứ tự thêm"),
  newest("Mới thêm trước"),
  nameAsc("Tên A → Z"),
  category("Theo danh mục"),
  priceAsc("Đơn giá thấp → cao"),
  priceDesc("Đơn giá cao → thấp"),
  stockAsc("Tồn kho ít → nhiều");

  final String label;
  const ComponentSort(this.label);
}

@MappableClass()
class ComponentSearchParams extends PagingSearchParams
    with ComponentSearchParamsMappable {
  int? projectId;
  int? projectOptionId;
  String name;

  /// Lọc theo danh mục (0 = chưa phân loại). Rỗng = không lọc.
  final List<int> categoryIds;

  /// Lọc theo loại (0 = chưa xác định loại). Rỗng = không lọc.
  final List<int> typeIds;

  final StockFilter stockFilter;
  final ComponentSort sort;

  ComponentSearchParams({
    this.projectId,
    this.projectOptionId,
    this.name = "",
    this.categoryIds = const [],
    this.typeIds = const [],
    this.stockFilter = StockFilter.all,
    this.sort = ComponentSort.added,
    super.page = 0,
    super.size = 12,
    super.searchOptions,
    super.focusId,
  });

  bool get hasFilter =>
      categoryIds.isNotEmpty ||
      typeIds.isNotEmpty ||
      stockFilter != StockFilter.all;
}
