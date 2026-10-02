import 'dart:convert';

import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:component_companion/util/text_search.dart';

/// 1 dòng đọc được từ file đơn hàng / BOM.
class ImportRow {
  final String name;

  /// Phân loại hàng của shop (VD "Gói 10 cái", "8mm + Ốc") => tên tuỳ chọn.
  final String packName;

  /// Thông số của biến thể, VD {"Điện áp": "5V", "Kiểu": "Active"}.
  final VariantSelection attributes;
  final int price;
  final int units;

  /// Số lượng đã mua (số gói) — dùng để cộng tồn kho nếu chọn.
  final int quantity;
  final String link;
  final String shop;

  const ImportRow({
    required this.name,
    this.packName = "",
    this.attributes = const {},
    this.price = 0,
    this.units = 1,
    this.quantity = 0,
    this.link = "",
    this.shop = "",
  });

  bool get hasOption =>
      price > 0 || link.isNotEmpty || shop.isNotEmpty || packName.isNotEmpty;

  String get attributesLabel => Variants.label(attributes);
}

/// Kế hoạch nhập cho 1 dòng (đã nhận diện danh mục / loại / linh kiện có sẵn).
class ImportPlan {
  final ImportRow row;
  bool include;
  int categoryId;
  int typeId;

  /// Linh kiện đã có cùng tên (sẽ thêm biến thể / tuỳ chọn vào) — null = tạo mới.
  final Component? existing;

  ImportPlan({
    required this.row,
    required this.categoryId,
    required this.typeId,
    this.existing,
    this.include = true,
  });
}

class ImportResult {
  final int created;
  final int variantsCreated;
  final int optionsAdded;
  final int stocked;

  const ImportResult(
    this.created,
    this.variantsCreated,
    this.optionsAdded,
    this.stocked,
  );
}

class ImportService {
  final _db = ObjectboxService.instance;

  // Tên cột được nhận diện (so khớp không dấu, không phân biệt hoa thường)
  static const _nameKeys = [
    "ten linh kien",
    "clean_name",
    "ten san pham",
    "ten",
    "name",
    "san pham",
    "product",
    "raw_name",
  ];
  static const _packKeys = [
    "phan loai",
    "phan loai hang",
    "quy cach",
    "goi",
    "variant",
    "pack",
  ];
  static const _attributeKeys = [
    "thuoc tinh",
    "thong so",
    "bien the",
    "attributes",
  ];
  static const _priceKeys = [
    "gia goi",
    "gia",
    "don gia",
    "gia/goi",
    "price",
    "unit_price",
  ];
  static const _unitsKeys = [
    "so cai/goi",
    "so cai moi goi",
    "so cai",
    "units",
    "units_per_pack",
  ];
  static const _quantityKeys = [
    "so luong mua",
    "so luong",
    "so goi",
    "quantity",
    "qty",
    "sl",
  ];
  static const _linkKeys = ["link", "url", "duong dan"];
  static const _shopKeys = ["shop", "cua hang", "nguoi ban", "seller", "store"];

  /// File CSV mẫu (có ví dụ) để người dùng điền theo.
  static String templateCsv() => Csv.encode([
    [
      "Tên linh kiện",
      "Thuộc tính",
      "Phân loại",
      "Số cái/gói",
      "Giá gói",
      "Số lượng mua",
      "Shop",
      "Link",
    ],
    [
      "Còi chip 12x9.5mm",
      "Điện áp=5V; Kiểu=Active",
      "Gói 5 cái",
      5,
      12000,
      1,
      "Linh kiện ABC",
      "https://shopee.vn/...",
    ],
    [
      "Còi chip 12x9.5mm",
      "Điện áp=12V; Kiểu=Active",
      "Gói 5 cái",
      5,
      12000,
      0,
      "Linh kiện ABC",
      "https://shopee.vn/...",
    ],
    [
      "Điện trở dán 1206",
      "Giá trị=10K",
      "Cuộn 100 cái",
      100,
      15000,
      2,
      "Shop XYZ",
      "",
    ],
    ["ESP32-C3 SuperMini", "", "1 cái", 1, 65000, 3, "Shop XYZ", ""],
  ]);

  /// Hướng dẫn các cột (hiển thị cạnh nút tải mẫu).
  static const templateHelp = [
    (
      "Tên linh kiện",
      "Bắt buộc. Trùng tên linh kiện đã có thì thêm vào linh kiện đó.",
    ),
    (
      "Thuộc tính",
      "Tuỳ chọn. Dạng \"Tên=Giá trị; Tên=Giá trị\" — mỗi tổ hợp là 1 biến thể.",
    ),
    ("Phân loại", "Tên tuỳ chọn mua của shop, VD \"Gói 10 cái\"."),
    ("Số cái/gói", "Số cái trong 1 gói (mặc định 1)."),
    ("Giá gói", "Giá cả gói, VD 25.000 hoặc 25000đ."),
    ("Số lượng mua", "Số gói đã mua — dùng khi chọn cộng vào tồn kho."),
    ("Shop", "Tên shop. Chưa có thì tự tạo."),
    ("Link", "Link sản phẩm."),
  ];

  static String _norm(String s) => TextSearch(
    s,
    const SearchOptions(caseMode: SearchCaseMode.insensitive),
  ).normalizedQuery;

  /// "Điện áp=5V; Kiểu=Active" => {"Điện áp": "5V", "Kiểu": "Active"}.
  static VariantSelection parseAttributes(String text) {
    final result = <String, String>{};
    for (final part in text.split(RegExp(r'[;|\n]'))) {
      final i = part.indexOf(RegExp(r'[=:]'));
      if (i <= 0) continue;
      final name = part.substring(0, i).trim();
      final value = part.substring(i + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) result[name] = value;
    }
    return result;
  }

  /// Đọc file CSV hoặc JSON (mảng object) thành các dòng.
  static List<ImportRow> parse(String content) {
    final text = content.trim();
    if (text.isEmpty) return const [];
    final List<Map<String, String>> records;
    if (text.startsWith("[")) {
      final Object? data;
      try {
        data = jsonDecode(text);
      } catch (_) {
        throw ValidationException("File JSON không hợp lệ");
      }
      if (data is! List) throw ValidationException("JSON phải là một mảng");
      records = [
        for (final item in data.whereType<Map>())
          {
            for (final e in item.entries)
              _norm("${e.key}"): e.value == null ? "" : "${e.value}",
          },
      ];
    } else {
      final rows = Csv.decode(text);
      if (rows.length < 2) {
        throw ValidationException(
          "CSV cần dòng tiêu đề và ít nhất 1 dòng dữ liệu",
        );
      }
      final header = rows.first.map(_norm).toList();
      records = [
        for (final row in rows.skip(1))
          {
            for (var i = 0; i < header.length && i < row.length; i++)
              header[i]: row[i],
          },
      ];
    }

    String pick(Map<String, String> r, List<String> keys) {
      for (final key in keys) {
        final value = r[key]?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return "";
    }

    int number(String s) =>
        int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    final result = <ImportRow>[];
    for (final r in records) {
      final name = pick(r, _nameKeys);
      if (name.isEmpty) continue;
      final units = number(pick(r, _unitsKeys));
      result.add(
        ImportRow(
          name: name,
          packName: pick(r, _packKeys),
          attributes: parseAttributes(pick(r, _attributeKeys)),
          price: number(pick(r, _priceKeys)),
          units: units <= 0 ? 1 : units,
          quantity: number(pick(r, _quantityKeys)),
          link: pick(r, _linkKeys),
          shop: pick(r, _shopKeys),
        ),
      );
    }
    if (result.isEmpty) {
      throw ValidationException(
        "Không tìm thấy cột tên linh kiện (cần cột: Tên linh kiện / name / clean_name)",
      );
    }
    return result;
  }

  /// Nhận diện danh mục, loại và linh kiện đã có cho từng dòng.
  List<ImportPlan> plan(List<ImportRow> rows) {
    final categories = _db.get<Category>().getAll();
    final types = _db.get<ComponentType>().getAll();
    final existing = {
      for (final c in _db.get<Component>().getAll()) c.name.toLowerCase(): c,
    };

    return [
      for (final row in rows)
        () {
          final found = existing[row.name.toLowerCase()];
          final type = KeywordMatcher.bestMatch(
            row.name,
            types,
            (t) => t.keywords,
          );
          final categoryId =
              KeywordMatcher.bestMatch(
                row.name,
                categories,
                (c) => c.keywords,
              )?.id ??
              type?.category.targetId ??
              0;
          return ImportPlan(
            row: row,
            existing: found,
            categoryId: found?.category.targetId ?? categoryId,
            typeId: found?.type.targetId ?? type?.id ?? 0,
          );
        }(),
    ];
  }

  /// Ghi các dòng được chọn.
  /// - Dòng trùng tên => cùng 1 linh kiện; thuộc tính mới được bổ sung.
  /// - Mỗi tổ hợp thuộc tính => 1 biến thể.
  /// - Dòng cùng shop + phân loại + số cái/gói + giá => gộp thành 1 tuỳ chọn
  ///   áp dụng cho nhiều biến thể.
  ImportResult apply(List<ImportPlan> plans, {bool addToStock = false}) {
    final componentBox = _db.get<Component>();
    final variantBox = _db.get<ComponentVariant>();
    final optionBox = _db.get<ComponentOption>();
    final priceBox = _db.get<PriceRecord>();
    final shopBox = _db.get<Shop>();

    return _db.store.runInTransaction(TxMode.write, () {
      var created = 0;
      var variantsCreated = 0;
      var optionsAdded = 0;
      var stocked = 0;
      final now = DateTime.now();
      final shops = {
        for (final s in shopBox.getAll()) s.name.trim().toLowerCase(): s,
      };
      Shop? shopOf(String name) {
        if (name.trim().isEmpty) return null;
        return shops.putIfAbsent(name.trim().toLowerCase(), () {
          final shop = Shop(name: name.trim());
          shopBox.put(shop);
          return shop;
        });
      }

      final included = plans.where((p) => p.include).toList();

      // 1. Linh kiện + thuộc tính (gộp mọi dòng cùng tên)
      final components = <String, Component>{};
      for (final plan in included) {
        final key = plan.row.name.toLowerCase();
        final component = components.putIfAbsent(key, () {
          final existing = plan.existing;
          if (existing != null) return componentBox.get(existing.id)!;
          created++;
          final c = Component(name: plan.row.name)
            ..category.targetId = plan.categoryId
            ..type.targetId = plan.typeId;
          componentBox.put(c);
          return c;
        });
        final attributes = [...component.attributes];
        var changed = false;
        plan.row.attributes.forEach((name, value) {
          final i = attributes.indexWhere(
            (a) => a.name.toLowerCase() == name.toLowerCase(),
          );
          if (i < 0) {
            attributes.add(VariantAttribute(name, [value]));
            changed = true;
          } else if (!attributes[i].values.contains(value)) {
            attributes[i] = VariantAttribute(attributes[i].name, [
              ...attributes[i].values,
              value,
            ]);
            changed = true;
          }
        });
        if (changed) {
          component.attributes = attributes;
          componentBox.put(component);
        }
      }

      // 2. Biến thể, tuỳ chọn, tồn kho
      for (final plan in included) {
        final row = plan.row;
        final component = components[row.name.toLowerCase()]!;
        final attributes = component.attributes;
        final variants = variantBox
            .query(ComponentVariant_.component.equals(component.id))
            .findAndClose();

        // Chuẩn hoá tên thuộc tính theo cách viết của linh kiện
        final selection = <String, String>{
          for (final a in attributes)
            for (final e in row.attributes.entries)
              if (e.key.toLowerCase() == a.name.toLowerCase()) a.name: e.value,
        };

        // Biến thể áp dụng cho dòng này
        List<ComponentVariant> targets;
        if (attributes.isEmpty || selection.length == attributes.length) {
          final key = Variants.key(attributes.isEmpty ? const {} : selection);
          var variant = variants
              .where((v) => Variants.key(v.selection) == key)
              .firstOrNull;
          if (variant == null) {
            variant = ComponentVariant(
              selectionJson: Variants.encodeSelection(
                attributes.isEmpty ? const {} : selection,
              ),
            )..component.targetId = component.id;
            variantBox.put(variant);
            variantsCreated++;
          }
          targets = [variant];
        } else {
          // Thiếu thông số => áp dụng cho các biến thể khớp phần đã ghi
          targets = variants
              .where(
                (v) => selection.entries.every(
                  (e) => v.selection[e.key] == e.value,
                ),
              )
              .toList();
        }

        if (row.hasOption && targets.isNotEmpty) {
          final name = row.packName.isEmpty
              ? "Gói ${row.units} cái"
              : row.packName;
          final shop = shopOf(row.shop);
          final same = optionBox
              .query(
                ComponentOption_.component.equals(component.id) &
                    ComponentOption_.name.equals(name) &
                    ComponentOption_.shop.equals(shop?.id ?? 0) &
                    ComponentOption_.unitsPerPack.equals(row.units) &
                    ComponentOption_.pricePerPack.equals(row.price),
              )
              .findFirstAndClose();
          if (same != null) {
            final missing = targets.where(
              (t) => !same.variants.any((v) => v.id == t.id),
            );
            if (missing.isNotEmpty) {
              same.variants.addAll(missing);
              optionBox.put(same);
            }
          } else {
            final option =
                ComponentOption(
                    name: name,
                    unitsPerPack: row.units,
                    pricePerPack: row.price,
                    link: row.link,
                    priceCheckedAt: now,
                  )
                  ..component.targetId = component.id
                  ..shop.target = shop;
            option.variants.addAll(targets);
            final optionId = optionBox.put(option);
            priceBox.put(
              PriceRecord(
                pricePerPack: row.price,
                unitsPerPack: row.units,
                recordedAt: now,
              )..option.targetId = optionId,
            );
            optionsAdded++;
          }
        }

        if (addToStock && row.quantity > 0 && targets.length == 1) {
          final variant = variantBox.get(targets.single.id)!;
          variant.stock = (variant.stock ?? 0) + row.quantity * row.units;
          variantBox.put(variant);
          stocked++;
        }
      }
      return ImportResult(created, variantsCreated, optionsAdded, stocked);
    });
  }
}
