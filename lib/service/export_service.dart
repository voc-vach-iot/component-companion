import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/util/price_insight.dart';

/// Xuất dữ liệu ra CSV (mở bằng Excel / Google Sheets).
class ExportService {
  final _db = ObjectboxService.instance;

  /// Mỗi cặp (biến thể, tuỳ chọn mua) 1 dòng; biến thể chưa có tuỳ chọn vẫn có 1 dòng.
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
        "Vị trí",
        "Shop",
        "Tùy chọn",
        "Số cái/gói",
        "Giá/gói",
        "Đơn giá",
        "Giá kiểm tra ngày",
        "Link",
      ],
    ];
    for (final c in components) {
      for (final v in c.sortedVariants) {
        final base = [
          c.name,
          c.category.target?.name ?? "",
          c.type.target?.name ?? "",
          v.isDefault ? "" : v.labelFor(c.attributes),
          v.stock ?? "",
          v.location,
        ];
        final options = v.options.toList()
          ..sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
        if (options.isEmpty) rows.add([...base, "", "", "", "", "", "", ""]);
        for (final o in options) {
          rows.add([
            ...base,
            o.shopName,
            o.name,
            o.unitsPerPack,
            o.pricePerPack,
            o.pricePerUnit.round(),
            o.priceCheckedAt == null
                ? ""
                : PriceInsight.formatDate(o.priceCheckedAt!),
            o.link,
          ]);
        }
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
        final v = i.variant.target;
        final o = i.componentOption.target;
        rows.add([
          section,
          c?.name ?? "(đã xoá)",
          v == null || v.isDefault ? "" : v.labelFor(c?.attributes),
          c?.category.target?.name ?? "",
          i.quantity,
          v?.stock ?? "",
          o?.shopName ?? "",
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
