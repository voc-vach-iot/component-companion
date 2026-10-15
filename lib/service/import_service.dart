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
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/service/stock_ledger.dart';
import 'package:component_companion/util/bom_parser.dart';
import 'package:component_companion/util/shop_name.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:component_companion/util/text_search.dart';

/// Đơn hàng của dòng đã giao chưa (quyết định nhập kho hay "đang về").
enum ImportDelivery {
  /// Đã nhận / không rõ trạng thái => cộng tồn kho.
  received,

  /// Chờ xác nhận / chờ giao / đang giao => cộng "đang về".
  pending,

  /// Đã huỷ / trả hàng => không cộng.
  cancelled,
}

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

  /// Trạng thái đơn (VD "Chờ giao hàng", "Hoàn thành").
  final String status;

  /// Nguồn dữ liệu (VD "Shopee").
  final String source;

  const ImportRow({
    required this.name,
    this.packName = "",
    this.attributes = const {},
    this.price = 0,
    this.units = 1,
    this.quantity = 0,
    this.link = "",
    this.shop = "",
    this.status = "",
    this.source = "",
  });

  bool get hasOption =>
      price > 0 || link.isNotEmpty || shop.isNotEmpty || packName.isNotEmpty;

  String get attributesLabel => Variants.label(attributes);

  bool get isShopee =>
      source.toLowerCase().contains("shopee") ||
      link.toLowerCase().contains("shopee.") ||
      ShopName.isShopee(shop);

  /// Tên shop sẽ dùng: hàng Shopee => thêm hậu tố " (Shopee)".
  String get shopName => isShopee ? ShopName.shopee(shop) : shop.trim();

  ImportDelivery get delivery {
    final s = ImportService._norm(status);
    if (RegExp(r'huy|tra hang|hoan tien').hasMatch(s)) {
      return ImportDelivery.cancelled;
    }
    if (RegExp(r'\bcho\b|dang giao|van chuyen|dang xu ly').hasMatch(s)) {
      return ImportDelivery.pending;
    }
    return ImportDelivery.received;
  }

  /// Tên + thuộc tính + phân loại — dùng để đoán linh kiện / biến thể.
  String get description => [
    name,
    ...attributes.values,
    packName,
  ].where((s) => s.isNotEmpty).join(" ");
}

/// Cách một dòng được nhận ra là linh kiện có sẵn.
enum ImportMatch {
  /// Không khớp => tạo linh kiện mới.
  none,

  /// Link trùng link của 1 tùy chọn mua đã có.
  link,

  /// Trùng tên y hệt (không phân biệt hoa thường).
  name,

  /// Đoán theo từ trong tên ([BomParser.matchComponent]).
  guess,

  /// Người dùng chọn tay.
  manual,
}

/// Kế hoạch nhập cho 1 dòng (đã nhận diện danh mục / loại / linh kiện có sẵn).
/// Các trường đổi được trên màn xem trước.
class ImportPlan {
  final ImportRow row;
  bool include;
  int categoryId;
  int typeId;

  /// Tên linh kiện sẽ tạo (khi [existing] null).
  String name;

  /// Linh kiện có sẵn sẽ thêm biến thể / tuỳ chọn vào — null = tạo mới.
  Component? existing;
  ImportMatch match;

  /// Biến thể có sẵn được chọn — null = theo [attributes] (tạo nếu chưa có).
  int? variantId;

  /// Thuộc tính của biến thể (mặc định lấy từ dòng, sửa được khi tạo biến thể mới).
  VariantSelection attributes;

  /// Tuỳ chọn mua có cùng link => chỉ cập nhật giá / số cái mỗi gói.
  ComponentOption? linkedOption;

  ImportPlan({
    required this.row,
    required this.categoryId,
    required this.typeId,
    this.existing,
    this.match = ImportMatch.none,
    this.variantId,
    this.linkedOption,
    VariantSelection? attributes,
    String? name,
    this.include = true,
  }) : attributes = attributes ?? row.attributes,
       name = name ?? row.name;

  /// Đổi sang linh kiện khác (null = tạo mới) do người dùng chọn.
  void selectComponent(Component? component) {
    existing = component;
    match = component == null ? ImportMatch.none : ImportMatch.manual;
    attributes = row.attributes;
    variantId = component == null
        ? null
        : BomParser.matchVariant(row.description, component)?.id;
    if (linkedOption?.component.targetId != component?.id) linkedOption = null;
  }
}

/// Shop cũ chưa có hậu tố "(Shopee)": [merge] = đã có shop mang tên mới
/// (nên gộp), ngược lại sẽ đổi tên khi nhập.
typedef ImportShopHint = ({String from, String to, bool merge});

/// Những gì 1 lần nhập đã tạo / sửa, để hoàn tác.
class ImportUndo {
  final shopIds = <int>[];
  final componentIds = <int>[];
  final variantIds = <int>[];
  final optionIds = <int>[];
  final priceRecordIds = <int>[];

  /// Giá trị cũ của bản ghi có sẵn bị sửa.
  final componentAttributes = <int, String>{};
  final optionVariants = <int, Set<int>>{};
  final optionPrices = <int, (int price, int units, DateTime? checkedAt)>{};
  final variantStocks = <int, int?>{};
  final variantIncoming = <int, int>{};
  final shopNames = <int, String>{};
}

class ImportResult {
  final int created;
  final int variantsCreated;
  final int optionsAdded;
  final int pricesUpdated;
  final int stocked;

  /// Số dòng cộng vào "đang về" (đơn chưa giao).
  final int incoming;

  /// Linh kiện đã tạo hoặc thêm dữ liệu (theo thứ tự dòng).
  final List<int> componentIds;
  final ImportUndo undo;

  const ImportResult({
    required this.created,
    required this.variantsCreated,
    required this.optionsAdded,
    required this.pricesUpdated,
    required this.stocked,
    required this.incoming,
    required this.componentIds,
    required this.undo,
  });

  String get summary => [
    "$created linh kiện mới",
    "$variantsCreated biến thể",
    "$optionsAdded tùy chọn mua",
    if (pricesUpdated > 0) "cập nhật giá $pricesUpdated tùy chọn",
    if (stocked > 0) "cộng kho $stocked dòng",
    if (incoming > 0) "$incoming dòng đang về",
  ].join(", ");
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
  static const _statusKeys = ["trang thai", "status"];
  static const _sourceKeys = ["nguon", "source"];

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
      "Bắt buộc. Giống tên linh kiện đã có (hoặc trùng link) thì gợi ý thêm vào linh kiện đó.",
    ),
    (
      "Thuộc tính",
      "Tuỳ chọn. Dạng \"Tên=Giá trị; Tên=Giá trị\" — mỗi tổ hợp là 1 biến thể.",
    ),
    ("Phân loại", "Tên tuỳ chọn mua của shop, VD \"Gói 10 cái\"."),
    ("Số cái/gói", "Số cái trong 1 gói (mặc định 1)."),
    ("Giá gói", "Giá cả gói, VD 25.000 hoặc 25000đ."),
    ("Số lượng mua", "Số gói đã mua — dùng khi chọn cộng vào tồn kho."),
    (
      "Shop",
      "Tên shop. Chưa có thì tự tạo. Hàng Shopee tự thêm hậu tố \"(Shopee)\".",
    ),
    (
      "Trạng thái",
      "Tuỳ chọn. Đơn chưa giao (Chờ giao, Đang giao...) => cộng vào \"đang về\"; đã huỷ => bỏ qua.",
    ),
    ("Link", "Link sản phẩm. Trùng link tùy chọn có sẵn => cập nhật giá."),
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
          status: pick(r, _statusKeys),
          source: pick(r, _sourceKeys),
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

  /// Khoá so sánh link: sản phẩm Shopee (`-i.<shop>.<item>` hoặc
  /// `/product/<shop>/<item>`) => `shopee:<shop>.<item>`; link khác => bỏ
  /// query, dấu `/` cuối, không phân biệt hoa thường. Rỗng => "".
  static String linkKey(String link) {
    final text = link.trim();
    if (text.isEmpty) return "";
    final shopee =
        RegExp(r'-i\.(\d+)\.(\d+)').firstMatch(text) ??
        RegExp(r'/product/(\d+)/(\d+)').firstMatch(text);
    if (shopee != null) return "shopee:${shopee[1]}.${shopee[2]}";
    return text
        .split(RegExp(r'[?#]'))
        .first
        .replaceFirst(RegExp(r'^https?://(www\.)?', caseSensitive: false), "")
        .replaceFirst(RegExp(r'/+$'), "")
        .toLowerCase();
  }

  static String _optionName(ImportRow row) =>
      row.packName.isEmpty ? "Gói ${row.units} cái" : row.packName;

  /// Nhận diện danh mục, loại và linh kiện đã có cho từng dòng:
  /// trùng link tuỳ chọn mua => trùng tên => đoán theo từ trong tên.
  List<ImportPlan> plan(List<ImportRow> rows) {
    final categories = _db.get<Category>().getAll();
    final types = _db.get<ComponentType>().getAll();
    final components = _db.get<Component>().getAll();
    final byName = {for (final c in components) c.name.toLowerCase(): c};
    final byLink = <String, List<ComponentOption>>{};
    for (final o in _db.get<ComponentOption>().getAll()) {
      final key = linkKey(o.link);
      if (key.isNotEmpty) byLink.putIfAbsent(key, () => []).add(o);
    }

    return [
      for (final row in rows)
        () {
          // Cùng link: ưu tiên tuỳ chọn cùng tên phân loại
          final sameLink = byLink[linkKey(row.link)] ?? const [];
          final optionName = _optionName(row).toLowerCase();
          final linked =
              sameLink
                  .where((o) => o.name.trim().toLowerCase() == optionName)
                  .firstOrNull ??
              (row.packName.isEmpty && sameLink.length == 1
                  ? sameLink.single
                  : null);
          final linkComponent = sameLink.isEmpty
              ? null
              : components
                    .where((c) => c.id == sameLink.first.component.targetId)
                    .firstOrNull;

          final (found, match) = switch ((
            linkComponent,
            byName[row.name.toLowerCase()],
          )) {
            (final c?, _) => (c, ImportMatch.link),
            (_, final c?) => (c, ImportMatch.name),
            _ => switch (BomParser.matchComponent(
              row.description,
              components,
            )) {
              final c? => (c, ImportMatch.guess),
              null => (null, ImportMatch.none),
            },
          };

          // Tuỳ chọn cùng link chỉ có 1 biến thể => dùng luôn biến thể đó
          final linkedVariants = linked?.variants ?? const [];
          final variantId = found == null
              ? null
              : row.attributes.isEmpty && linkedVariants.length == 1
              ? linkedVariants.single.id
              : BomParser.matchVariant(row.description, found)?.id;

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
            match: match,
            variantId: variantId,
            linkedOption: linked?.component.targetId == found?.id
                ? linked
                : null,
            categoryId: found?.category.targetId ?? categoryId,
            typeId: found?.type.targetId ?? type?.id ?? 0,
          );
        }(),
    ];
  }

  /// Ghi các dòng được chọn.
  /// - Dòng cùng linh kiện (có sẵn, hoặc cùng tên nếu tạo mới) => 1 linh kiện;
  ///   thuộc tính mới được bổ sung.
  /// - Mỗi tổ hợp thuộc tính => 1 biến thể (trừ khi đã chọn biến thể có sẵn).
  /// - Dòng trùng link tuỳ chọn có sẵn => cập nhật giá, ghi lịch sử giá.
  /// - Dòng cùng shop + phân loại + số cái/gói + giá => gộp thành 1 tuỳ chọn
  ///   áp dụng cho nhiều biến thể.
  /// - Hàng Shopee: shop có hậu tố " (Shopee)"; shop cũ cùng tên chưa có hậu
  ///   tố được đổi tên nếu [renameShops].
  /// - [addToStock]: đơn đã nhận => cộng tồn kho, đơn chưa giao => cộng
  ///   "đang về", đơn huỷ => bỏ qua.
  ImportResult apply(
    List<ImportPlan> plans, {
    bool addToStock = false,
    bool renameShops = true,
  }) {
    final componentBox = _db.get<Component>();
    final variantBox = _db.get<ComponentVariant>();
    final optionBox = _db.get<ComponentOption>();
    final priceBox = _db.get<PriceRecord>();
    final shopBox = _db.get<Shop>();
    final ledger = StockLedger();
    final undo = ImportUndo();

    return _db.store.runInTransaction(TxMode.write, () {
      var created = 0;
      var variantsCreated = 0;
      var optionsAdded = 0;
      var pricesUpdated = 0;
      var stocked = 0;
      var incoming = 0;
      final touched = <int>{};
      final now = DateTime.now();
      final shops = {
        for (final s in shopBox.getAll()) s.name.trim().toLowerCase(): s,
      };
      Shop? shopOf(ImportRow row) {
        final name = row.shopName;
        if (name.isEmpty) return null;
        final key = name.toLowerCase();
        if (shops[key] case final shop?) return shop;
        // Shop cũ chưa có hậu tố (Shopee)
        if (row.isShopee) {
          final old = shops[ShopName.base(name).toLowerCase()];
          if (old != null) {
            if (!renameShops) return old;
            undo.shopNames.putIfAbsent(old.id, () => old.name);
            shops.remove(old.name.trim().toLowerCase());
            old.name = name;
            shopBox.put(old);
            return shops[key] = old;
          }
        }
        final shop = Shop(name: name);
        undo.shopIds.add(shopBox.put(shop));
        return shops[key] = shop;
      }

      void recordPrice(ComponentOption option) => undo.priceRecordIds.add(
        priceBox.put(
          PriceRecord(
            pricePerPack: option.pricePerPack,
            unitsPerPack: option.unitsPerPack,
            recordedAt: now,
          )..option.targetId = option.id,
        ),
      );

      void linkVariants(
        ComponentOption option,
        List<ComponentVariant> targets,
      ) {
        final missing = targets.where(
          (t) => !option.variants.any((v) => v.id == t.id),
        );
        if (missing.isEmpty) return;
        undo.optionVariants.putIfAbsent(
          option.id,
          () => {for (final v in option.variants) v.id},
        );
        option.variants.addAll(missing);
        optionBox.put(option);
      }

      String keyOf(ImportPlan plan) => plan.existing == null
          ? plan.name.trim().toLowerCase()
          : "#${plan.existing!.id}";

      final included = plans.where((p) => p.include).toList();

      // 1. Linh kiện + thuộc tính
      final components = <String, Component>{};
      for (final plan in included) {
        final component = components.putIfAbsent(keyOf(plan), () {
          final existing = plan.existing;
          if (existing != null) return componentBox.get(existing.id)!;
          created++;
          final c = Component(name: plan.name.trim())
            ..category.targetId = plan.categoryId
            ..type.targetId = plan.typeId;
          undo.componentIds.add(componentBox.put(c));
          return c;
        });
        if (plan.variantId != null) continue;
        final attributes = [...component.attributes];
        var changed = false;
        plan.attributes.forEach((name, value) {
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
          if (!undo.componentIds.contains(component.id)) {
            undo.componentAttributes.putIfAbsent(
              component.id,
              () => componentBox.get(component.id)!.attributesJson,
            );
          }
          component.attributes = attributes;
          componentBox.put(component);
        }
      }

      // 2. Biến thể, tuỳ chọn, tồn kho
      for (final plan in included) {
        final row = plan.row;
        final component = components[keyOf(plan)]!;
        touched.add(component.id);
        final linked = plan.linkedOption == null
            ? null
            : optionBox.get(plan.linkedOption!.id);

        // Biến thể áp dụng cho dòng này
        List<ComponentVariant> targets;
        final chosen = plan.variantId == null
            ? null
            : variantBox.get(plan.variantId!);
        if (chosen != null) {
          targets = [chosen];
        } else if (linked != null && plan.attributes.isEmpty) {
          targets = linked.variants.toList();
        } else {
          final attributes = component.attributes;
          final variants = variantBox
              .query(ComponentVariant_.component.equals(component.id))
              .findAndClose();

          // Chuẩn hoá tên thuộc tính theo cách viết của linh kiện
          final selection = <String, String>{
            for (final a in attributes)
              for (final e in plan.attributes.entries)
                if (e.key.toLowerCase() == a.name.toLowerCase())
                  a.name: e.value,
          };

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
              undo.variantIds.add(variantBox.put(variant));
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
        }

        if (linked != null) {
          // Cùng link => cập nhật giá, giá cũ còn trong lịch sử
          if (row.price > 0 &&
              (linked.pricePerPack != row.price ||
                  linked.unitsPerPack != row.units)) {
            undo.optionPrices.putIfAbsent(
              linked.id,
              () => (
                linked.pricePerPack,
                linked.unitsPerPack,
                linked.priceCheckedAt,
              ),
            );
            linked
              ..pricePerPack = row.price
              ..unitsPerPack = row.units
              ..priceCheckedAt = now;
            optionBox.put(linked);
            recordPrice(linked);
            pricesUpdated++;
          }
          linkVariants(linked, targets);
        } else if (row.hasOption && targets.isNotEmpty) {
          final name = _optionName(row);
          final shop = shopOf(row);
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
            linkVariants(same, targets);
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
            undo.optionIds.add(optionBox.put(option));
            recordPrice(option);
            optionsAdded++;
          }
        }

        if (addToStock && row.quantity > 0 && targets.length == 1) {
          final variant = variantBox.get(targets.single.id)!;
          final units = row.quantity * row.units;
          switch (row.delivery) {
            case ImportDelivery.received:
              undo.variantStocks.putIfAbsent(variant.id, () => variant.stock);
              ledger.adjust(
                variant,
                units,
                StockReason.import,
                note: row.status,
              );
              stocked++;
            case ImportDelivery.pending:
              undo.variantIncoming.putIfAbsent(
                variant.id,
                () => variant.incoming,
              );
              variant.incoming += units;
              variantBox.put(variant);
              incoming++;
            case ImportDelivery.cancelled:
          }
        }
      }
      return ImportResult(
        created: created,
        variantsCreated: variantsCreated,
        optionsAdded: optionsAdded,
        pricesUpdated: pricesUpdated,
        stocked: stocked,
        incoming: incoming,
        componentIds: touched.toList(),
        undo: undo,
      );
    });
  }

  /// Shop cũ thiếu hậu tố "(Shopee)" sẽ được đổi tên: tên cũ -> tên mới.
  /// Shop đã có cả 2 tên => [ImportShopHint.merge] (nên gộp ở trang Shop).
  List<ImportShopHint> shopHints(Iterable<ImportPlan> plans) {
    final shops = {
      for (final s in _db.get<Shop>().getAll()) s.name.trim().toLowerCase(): s,
    };
    final result = <String, ImportShopHint>{};
    for (final p in plans.where((p) => p.include && p.row.isShopee)) {
      final name = p.row.shopName;
      if (name.isEmpty) continue;
      final old = shops[ShopName.base(name).toLowerCase()];
      if (old == null) continue;
      final both = shops.containsKey(name.toLowerCase());
      result[old.name] = (from: old.name, to: name, merge: both);
    }
    return result.values.toList();
  }

  /// Hoàn tác 1 lần nhập: xoá bản ghi đã tạo, trả lại giá trị cũ.
  void undo(ImportUndo undo) {
    final componentBox = _db.get<Component>();
    final variantBox = _db.get<ComponentVariant>();
    final optionBox = _db.get<ComponentOption>();

    final ledger = StockLedger();

    _db.store.runInTransaction(TxMode.write, () {
      undo.variantStocks.forEach((id, stock) {
        final variant = variantBox.get(id);
        if (variant != null) ledger.set(variant, stock, StockReason.undo);
      });
      undo.variantIncoming.forEach((id, incoming) {
        final variant = variantBox.get(id);
        if (variant == null) return;
        variant.incoming = incoming;
        variantBox.put(variant);
      });
      final shopBox = _db.get<Shop>();
      undo.shopNames.forEach((id, name) {
        final shop = shopBox.get(id);
        if (shop == null) return;
        shop.name = name;
        shopBox.put(shop);
      });
      final optionIds = {
        ...undo.optionPrices.keys,
        ...undo.optionVariants.keys,
      };
      for (final id in optionIds) {
        final option = optionBox.get(id);
        if (option == null) continue;
        if (undo.optionPrices[id] case (final price, final units, final at)) {
          option
            ..pricePerPack = price
            ..unitsPerPack = units
            ..priceCheckedAt = at;
        }
        if (undo.optionVariants[id] case final keep?) {
          for (final v in [...option.variants]) {
            if (!keep.contains(v.id)) option.variants.remove(v);
          }
        }
        optionBox.put(option);
      }
      undo.componentAttributes.forEach((id, json) {
        final component = componentBox.get(id);
        if (component == null) return;
        component.attributesJson = json;
        componentBox.put(component);
      });
      _db.get<PriceRecord>().removeMany(undo.priceRecordIds);
      optionBox.removeMany(undo.optionIds);
      variantBox.removeMany(undo.variantIds);
      componentBox.removeMany(undo.componentIds);
      _db.get<Shop>().removeMany(undo.shopIds);
    });
  }
}
