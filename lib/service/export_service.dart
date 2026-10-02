import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/util/price_insight.dart';

/// Xuất dữ liệu ra CSV (mở bằng Excel / Google Sheets).
class ExportService {
  final _db = ObjectboxService.instance;

  /// Mỗi tuỳ chọn mua hàng 1 dòng (linh kiện chưa có tuỳ chọn vẫn có 1 dòng).
  String componentsCsv() {
    final components = _db.get<Component>().getAll()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final rows = <List<Object?>>[
      [
        "Linh kiện",
        "Danh mục",
        "Loại",
        "Biến thể",
        "Tồn kho",
        "Shop",
        "Tùy chọn",
        "Số cái/gói",
        "Giá/gói",
        "Đơn giá",
        "Áp dụng cho",
        "Giá kiểm tra ngày",
        "Link",
      ],
    ];
    for (final c in components) {
      final base = [
        c.name,
        c.category.target?.name ?? "",
        c.type.target?.name ?? "",
        [
          for (final a in c.attributes) "${a.name}: ${a.values.join("/")}",
        ].join("; "),
        c.stockTotal ?? "",
      ];
      final options = c.options.toList()
        ..sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
      if (options.isEmpty) {
        rows.add([...base, "", "", "", "", "", "", "", ""]);
      }
      for (final o in options) {
        rows.add([
          ...base,
          o.shop,
          o.name,
          o.unitsPerPack,
          o.pricePerPack,
          o.pricePerUnit.round(),
          Variants.availabilityLabel(o.availability),
          o.priceCheckedAt == null
              ? ""
              : PriceInsight.formatDate(o.priceCheckedAt!),
          o.link,
        ]);
      }
    }
    return Csv.encode(rows);
  }

  /// BOM của dự án: phần cơ bản + từng phiên bản.
  String projectBomCsv(Project project) {
    final rows = <List<Object?>>[
      [
        "Phần",
        "Linh kiện",
        "Biến thể",
        "Danh mục",
        "Số lượng",
        "Tồn kho",
        "Shop",
        "Tùy chọn",
        "Đơn giá",
        "Thành tiền",
        "Link",
      ],
    ];
    void addItems(String section, Iterable<ProjectItem> items) {
      for (final i in items) {
        final c = i.component.target;
        final o = i.componentOption.target;
        rows.add([
          section,
          c?.name ?? "(đã xoá)",
          Variants.label(i.variant, c?.attributes),
          c?.category.target?.name ?? "",
          i.quantity,
          c == null || c.stockItems.isEmpty ? "" : c.stockOf(i.variant),
          o?.shop ?? "",
          o?.name ?? "",
          o?.pricePerUnit.round() ?? "",
          i.totalPrice.round(),
          o?.link ?? "",
        ]);
      }
    }

    addItems("Cơ bản", project.baseItems);
    for (final version in project.projectOptions) {
      addItems(version.name, version.items);
    }
    return Csv.encode(rows);
  }
}
