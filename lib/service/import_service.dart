import 'dart:convert';

import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/combo_part.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/model/unit.dart';
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

  /// Tên / phân loại có dấu hiệu là combo nhiều linh kiện (VD "Combo LCD1602
  /// + PCF8574", "1 cặp đực cái") — chỉ để gợi ý, không tự tạo combo.
  bool get looksLikeCombo => RegExp(
    r'combo|\+|\bkem\b|\bcap\b|duc\W*(va\W*)?cai',
  ).hasMatch(ImportService._norm("$name $packName"));

  /// Tên + thuộc tính + phân loại — dùng để đoán linh kiện / biến thể.
  String get description => [
    name,
    ...attributes.values,
    packName,
  ].where((s) => s.isNotEmpty).join(" ");
}

/// Thành phần thêm của dòng combo (ngoài linh kiện của chính dòng đó): biến
/// thể có sẵn [variant], hoặc biến thể sẽ tạo khi nhập theo [selection] của
/// linh kiện có sẵn [component] / linh kiện mới tên [newName] (VD đầu cái của
/// "Jack XT60" vừa tạo trong lần nhập này).
class ImportComboPart {
  final ComponentVariant? variant;
  final Component? component;
  final String newName;
  final VariantSelection selection;
  final int quantity;

  const ImportComboPart.existing(
    ComponentVariant this.variant, [
    this.quantity = 1,
  ]) : component = null,
       newName = "",
       selection = const {};

  const ImportComboPart.draft({
    this.component,
    this.newName = "",
    this.selection = const {},
    this.quantity = 1,
  }) : variant = null;

  bool get isDraft => variant == null;

  /// Linh kiện đích như [ImportSession.targetKey].
  String get targetKey => component != null
      ? "#${component!.id}"
      : "new:${newName.trim().toLowerCase()}";

  String get label {
    if (variant case final v?) return v.fullLabel;
    final name = component?.name ?? newName.trim();
    return selection.isEmpty
        ? "$name (mới)"
        : "$name · Mới: ${Variants.label(selection, null)}";
  }

  /// Cùng biến thể (không tính số lượng).
  String get key => variant != null
      ? "v${variant!.id}"
      : "$targetKey|${Variants.key(selection)}";

  ImportComboPart withQuantity(int quantity) => variant != null
      ? ImportComboPart.existing(variant!, quantity)
      : ImportComboPart.draft(
          component: component,
          newName: newName,
          selection: selection,
          quantity: quantity,
        );

  @override
  bool operator ==(Object other) =>
      other is ImportComboPart && other.key == key;

  @override
  int get hashCode => key.hashCode;
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

  /// Icon SVG của linh kiện sẽ tạo (rỗng = dùng icon của loại).
  String iconSvg = "";

  /// Linh kiện có sẵn sẽ thêm biến thể / tuỳ chọn vào — null = tạo mới.
  Component? existing;
  ImportMatch match;

  /// Biến thể có sẵn được chọn — null = theo [attributes] (tạo nếu chưa có).
  int? variantId;

  /// Thuộc tính của biến thể (mặc định lấy từ dòng, sửa được khi tạo biến thể mới).
  VariantSelection attributes;

  /// Tuỳ chọn mua có cùng link => chỉ cập nhật giá / số cái mỗi gói.
  ComponentOption? linkedOption;

  /// Gợi ý ban đầu (để quay lại sau khi đổi sang tạo mới / linh kiện khác).
  final Component? suggested;
  final ImportMatch suggestedMatch;
  final int? _suggestedVariantId;
  final ComponentOption? _suggestedOption;

  /// Dòng là combo: 1 gói gồm [combosPerPack] combo, mỗi combo gồm
  /// [comboUnits] cái linh kiện của dòng này + các thành phần [comboExtras]
  /// (số lượng tính cho 1 combo), VD "10 cặp XT60" = 10 combo × (1 đực + 1
  /// cái). Rỗng = không phải combo.
  List<ImportComboPart> comboExtras = [];

  /// Số combo trong 1 gói (0 = theo số cái mỗi gói của dòng).
  int comboCount = 0;

  /// Số cái linh kiện của dòng trong 1 combo (0 = linh kiện của dòng không
  /// nằm trong combo, không cần chọn biến thể).
  int comboUnits = 1;

  bool get isCombo => comboExtras.isNotEmpty;
  int get combosPerPack => comboCount > 0 ? comboCount : row.units;

  /// Số cái linh kiện của dòng trong 1 gói.
  int get mainUnits => combosPerPack * comboUnits;

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
       name = name ?? row.name,
       suggested = existing,
       suggestedMatch = match,
       _suggestedVariantId = variantId,
       _suggestedOption = linkedOption;

  /// Linh kiện / biến thể đang chọn (để hoàn tác khi đổi nhiều dòng một lúc).
  ImportTargetState get targetState => (
    existing: existing,
    match: match,
    name: name,
    attributes: attributes,
    variantId: variantId,
    linkedOption: linkedOption,
  );

  void restoreTarget(ImportTargetState state) {
    existing = state.existing;
    match = state.match;
    name = state.name;
    attributes = state.attributes;
    variantId = state.variantId;
    linkedOption = state.linkedOption;
  }

  /// Đang dùng đúng gợi ý ban đầu.
  bool get usesSuggestion => suggested != null && existing?.id == suggested!.id;

  /// Bỏ khớp => tạo linh kiện mới theo tên của dòng.
  void createNew() {
    selectComponent(null);
    name = row.name;
  }

  /// Quay lại linh kiện được gợi ý ban đầu.
  void useSuggestion() {
    if (suggested == null) return;
    existing = suggested;
    match = suggestedMatch;
    attributes = row.attributes;
    variantId = _suggestedVariantId;
    linkedOption = _suggestedOption;
  }

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

typedef ImportTargetState = ({
  Component? existing,
  ImportMatch match,
  String name,
  VariantSelection attributes,
  int? variantId,
  ComponentOption? linkedOption,
});

/// Shop cũ chưa có hậu tố "(Shopee)": [merge] = đã có shop mang tên mới
/// (nên gộp), ngược lại sẽ đổi tên khi nhập.
typedef ImportShopHint = ({String from, String to, bool merge});

/// Những gì 1 lần nhập đã tạo / sửa, để hoàn tác.
class ImportUndo {
  final shopIds = <int>[];
  final componentIds = <int>[];
  final variantIds = <int>[];
  final optionIds = <int>[];
  final comboPartIds = <int>[];
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

  /// Biến thể [selection] không trái thuộc tính [attributes] của dòng (so tên
  /// thuộc tính và giá trị không phân biệt hoa thường).
  static bool _fitsAttributes(
    VariantSelection selection,
    VariantSelection attributes,
  ) {
    String key(String s) => _norm(s).trim();
    final values = {
      for (final e in selection.entries) key(e.key): key(e.value),
    };
    return attributes.entries.every((e) => values[key(e.key)] == key(e.value));
  }

  static String _optionName(
    ImportRow row, [
    QuantityUnit unit = QuantityUnit.piece,
  ]) => row.packName.isEmpty
      ? "Gói ${row.units} ${unit.label}"
      : row.packName;

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
          // Cùng link: ưu tiên tuỳ chọn cùng tên phân loại. Dòng có thuộc tính
          // (phân loại khác của cùng sản phẩm) chỉ khớp tuỳ chọn có biến thể
          // hợp thuộc tính, không thì tạo tuỳ chọn mới.
          final sameLink = byLink[linkKey(row.link)] ?? const [];
          final candidates = row.attributes.isEmpty
              ? sameLink
              : sameLink
                    .where(
                      (o) => o.variants.any(
                        (v) => _fitsAttributes(v.selection, row.attributes),
                      ),
                    )
                    .toList();
          final optionName = _optionName(row).toLowerCase();
          final linked =
              candidates
                  .where((o) => o.name.trim().toLowerCase() == optionName)
                  .firstOrNull ??
              (row.packName.isEmpty && candidates.length == 1
                  ? candidates.single
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
      void mergeAttributes(Component component, VariantSelection selection) {
        final isNew = undo.componentIds.contains(component.id);
        final attributes = [...component.attributes];
        var changed = false;
        selection.forEach((name, value) {
          final i = attributes.indexWhere(
            (a) => a.name.toLowerCase() == name.toLowerCase(),
          );
          if (i < 0) {
            // Không tự thêm thuộc tính lạ vào linh kiện có sẵn (VD Shopee ghi
            // "Dung lượng" còn linh kiện dùng "Dung lượng thẻ")
            if (!isNew) return;
            attributes.add(VariantAttribute(name, [value]));
            changed = true;
          } else if (!attributes[i].values.contains(value)) {
            final old = attributes[i].values;
            final values = [...old, value];
            // Giữ thứ tự tự nhiên nếu danh sách đang được sắp xếp
            attributes[i] = VariantAttribute(
              attributes[i].name,
              isNew || Variants.isSorted(old)
                  ? Variants.sortValues(values)
                  : values,
            );
            changed = true;
          }
        });
        if (changed) {
          if (!isNew) {
            undo.componentAttributes.putIfAbsent(
              component.id,
              () => componentBox.get(component.id)!.attributesJson,
            );
          }
          component.attributes = attributes;
          componentBox.put(component);
        }
      }

      for (final plan in included) {
        final component = components.putIfAbsent(keyOf(plan), () {
          final existing = plan.existing;
          if (existing != null) return componentBox.get(existing.id)!;
          created++;
          final c = Component(name: plan.name.trim(), iconSvg: plan.iconSvg)
            ..category.targetId = plan.categoryId
            ..type.targetId = plan.typeId;
          undo.componentIds.add(componentBox.put(c));
          return c;
        });
        if (plan.variantId == null) mergeAttributes(component, plan.attributes);
      }

      // Biến thể mới trong combo: linh kiện của nó (có sẵn / tạo ở dòng khác)
      Component componentOfPart(ImportComboPart part) {
        final key = part.component != null
            ? "#${part.component!.id}"
            : part.newName.trim().toLowerCase();
        if (components[key] case final c?) return c;
        if (part.component case final c?) {
          return components[key] = componentBox.get(c.id)!;
        }
        throw ValidationException(
          "Linh kiện \"${part.newName}\" trong combo không có trong lần nhập",
        );
      }

      for (final plan in included) {
        for (final part in plan.comboExtras.where((p) => p.isDraft)) {
          mergeAttributes(componentOfPart(part), part.selection);
        }
      }

      /// Biến thể của [component] theo [selection] (tạo nếu chưa có); null nếu
      /// lựa chọn thiếu thuộc tính.
      ComponentVariant? variantFor(
        Component component,
        VariantSelection selection,
      ) {
        final attributes = component.attributes;
        final normalized = <String, String>{
          for (final a in attributes)
            for (final e in selection.entries)
              if (e.key.toLowerCase() == a.name.toLowerCase()) a.name: e.value,
        };
        if (attributes.isNotEmpty && normalized.length != attributes.length) {
          return null;
        }
        final key = Variants.key(attributes.isEmpty ? const {} : normalized);
        final found = variantBox
            .query(ComponentVariant_.component.equals(component.id))
            .findAndClose()
            .where((v) => Variants.key(v.selection) == key)
            .firstOrNull;
        if (found != null) return found;
        final variant = ComponentVariant(
          selectionJson: Variants.encodeSelection(
            attributes.isEmpty ? const {} : normalized,
          ),
        )..component.targetId = component.id;
        undo.variantIds.add(variantBox.put(variant));
        variantsCreated++;
        return variant;
      }

      // 2. Biến thể, tuỳ chọn, tồn kho
      for (final plan in included) {
        final row = plan.row;
        final component = components[keyOf(plan)]!;
        touched.add(component.id);
        final linked = plan.linkedOption == null
            ? null
            : optionBox.get(plan.linkedOption!.id);
        // Số cái nhận được theo biến thể (combo mới tự điền bên dưới)
        Map<int, int>? received;

        // Biến thể áp dụng cho dòng này
        List<ComponentVariant> targets;
        final chosen = plan.variantId == null
            ? null
            : variantBox.get(plan.variantId!);
        if (linked == null && plan.isCombo && plan.comboUnits <= 0) {
          // Linh kiện của dòng không nằm trong combo
          targets = const [];
        } else if (chosen != null) {
          targets = [chosen];
        } else if (linked != null && plan.attributes.isEmpty) {
          targets = linked.variants.toList();
        } else if (variantFor(component, plan.attributes) case final v?) {
          targets = [v];
        } else {
          final variants = variantBox
              .query(ComponentVariant_.component.equals(component.id))
              .findAndClose();
          // Chuẩn hoá tên thuộc tính theo cách viết của linh kiện
          final selection = <String, String>{
            for (final a in component.attributes)
              for (final e in plan.attributes.entries)
                if (e.key.toLowerCase() == a.name.toLowerCase())
                  a.name: e.value,
          };
          // Thiếu thông số => áp dụng cho các biến thể khớp phần đã ghi
          targets = variants
              .where(
                (v) => selection.entries.every(
                  (e) => v.selection[e.key] == e.value,
                ),
              )
              .toList();
        }

        // Số trong file là theo đơn vị hiển thị (10 = 10 m): đổi sang số lưu
        final rawUnits = row.units * component.quantityUnit.scale;

        if (linked != null) {
          // Cùng link => cập nhật giá, giá cũ còn trong lịch sử
          // Combo: 1 gói = 1 combo, chỉ cập nhật giá
          final units = linked.isCombo ? linked.unitsPerPack : rawUnits;
          if (row.price > 0 &&
              (linked.pricePerPack != row.price ||
                  linked.unitsPerPack != units)) {
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
              ..unitsPerPack = units
              ..priceCheckedAt = now;
            optionBox.put(linked);
            recordPrice(linked);
            pricesUpdated++;
          }
          if (!linked.isCombo) linkVariants(linked, targets);
        } else if (plan.isCombo) {
          // Combo mới: 1 tuỳ chọn, số cái mỗi thành phần tính theo cả gói
          final quantities = <int, int>{};
          if (plan.mainUnits > 0) {
            if (targets.length != 1) {
              throw ValidationException(
                "Combo \"${row.name}\": chọn đúng 1 biến thể cho linh kiện "
                "của dòng, hoặc để 0 cái nếu nó không nằm trong combo",
              );
            }
            quantities[targets.single.id] = plan.mainUnits;
          }
          for (final p in plan.comboExtras) {
            if (p.quantity <= 0) continue;
            final units = plan.combosPerPack * p.quantity;
            final variant =
                p.variant ?? variantFor(componentOfPart(p), p.selection);
            if (variant == null) {
              throw ValidationException(
                "Combo \"${row.name}\": biến thể \"${p.label}\" thiếu thuộc tính",
              );
            }
            quantities.update(
              variant.id,
              (q) => q + units,
              ifAbsent: () => units,
            );
          }
          if (quantities.isEmpty) {
            throw ValidationException(
              "Combo \"${row.name}\" chưa có thành phần",
            );
          }
          final option =
              ComponentOption(
                  name: _optionName(row),
                  unitsPerPack: 1,
                  pricePerPack: row.price,
                  link: row.link,
                  priceCheckedAt: now,
                )
                ..component.targetId = component.id
                ..shop.target = shopOf(row);
          option.variants.addAll(
            variantBox
                .getMany(quantities.keys.toList())
                .whereType<ComponentVariant>(),
          );
          undo.optionIds.add(optionBox.put(option));
          undo.comboPartIds.addAll(
            _db.get<ComboPart>().putMany([
              for (final MapEntry(key: id, value: q) in quantities.entries)
                ComboPart(quantity: q)
                  ..variant.targetId = id
                  ..option.targetId = option.id,
            ]),
          );
          recordPrice(option);
          optionsAdded++;
          received = {
            for (final MapEntry(key: id, value: q) in quantities.entries)
              id: row.quantity * q,
          };
        } else if (row.hasOption && targets.isNotEmpty) {
          final name = _optionName(row, component.quantityUnit);
          final shop = shopOf(row);
          final same = optionBox
              .query(
                ComponentOption_.component.equals(component.id) &
                    ComponentOption_.name.equals(name) &
                    ComponentOption_.shop.equals(shop?.id ?? 0) &
                    ComponentOption_.unitsPerPack.equals(rawUnits) &
                    ComponentOption_.pricePerPack.equals(row.price),
              )
              .findFirstAndClose();
          if (same != null) {
            linkVariants(same, targets);
          } else {
            final option =
                ComponentOption(
                    name: name,
                    unitsPerPack: rawUnits,
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

        // Số cái nhận được theo biến thể: combo => mọi linh kiện trong combo
        received ??= linked != null && linked.isCombo
            ? <int, int>{
                for (final p in linked.parts)
                  if (p.variant.targetId != 0)
                    p.variant.targetId: row.quantity * p.quantity,
              }
            : <int, int>{
                if (targets.length == 1)
                  targets.single.id: row.quantity * rawUnits,
              };
        if (addToStock && row.quantity > 0 && received.isNotEmpty) {
          for (final MapEntry(key: variantId, value: units)
              in received.entries) {
            final variant = variantBox.get(variantId);
            if (variant == null || units <= 0) continue;
            switch (row.delivery) {
              case ImportDelivery.received:
                undo.variantStocks.putIfAbsent(variant.id, () => variant.stock);
                ledger.adjust(
                  variant,
                  units,
                  StockReason.import,
                  note: row.status,
                );
              case ImportDelivery.pending:
                undo.variantIncoming.putIfAbsent(
                  variant.id,
                  () => variant.incoming,
                );
                variant.incoming += units;
                variantBox.put(variant);
              case ImportDelivery.cancelled:
            }
          }
          // Đếm theo dòng nhập (combo nhiều linh kiện vẫn là 1 dòng)
          switch (row.delivery) {
            case ImportDelivery.received:
              stocked++;
            case ImportDelivery.pending:
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

  /// Đoán giá trị biến thể cho dòng [other] theo cách người dùng đã điền ở
  /// dòng [example] ([selection]): giá trị lấy từ cột Thuộc tính / Phân loại
  /// nào của [example] thì lấy cùng cột đó của [other]; giá trị có số (VD
  /// "16GB") được tìm theo mẫu ("32GB", "64 GB"). null nếu thiếu thuộc tính nào.
  static VariantSelection? inferSelection(
    ImportRow example,
    VariantSelection selection,
    ImportRow other,
  ) {
    final result = <String, String>{};
    for (final MapEntry(key: name, value: value) in selection.entries) {
      final found = _inferValue(example, value, other);
      if (found == null) return null;
      result[name] = found;
    }
    return result;
  }

  static String? _inferValue(ImportRow example, String value, ImportRow other) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return null;
    String? attrOf(ImportRow row, String key) => row.attributes.entries
        .where((e) => e.key.toLowerCase() == key.toLowerCase())
        .firstOrNull
        ?.value;

    // Cột của dòng mẫu chứa giá trị: (tên thuộc tính | null = Phân loại, chữ)
    final fields = <(String?, String)>[
      (null, example.packName),
      for (final e in example.attributes.entries) (e.key, e.value),
    ];
    // 1. Trùng nguyên ô => lấy nguyên ô tương ứng
    for (final (key, text) in fields) {
      if (text.trim().toLowerCase() != v) continue;
      final target = key == null ? other.packName : attrOf(other, key);
      if (target != null && target.trim().isNotEmpty) return target.trim();
    }
    // 2. Nằm trong ô => tìm theo mẫu trong ô tương ứng
    final pattern = _valuePattern(value);
    for (final (key, text) in fields) {
      if (!pattern.allMatches(text).any((m) => m[0]!.toLowerCase() == v)) {
        continue;
      }
      final target = key == null ? other.packName : attrOf(other, key) ?? "";
      final matches = pattern.allMatches(target).map((m) => m[0]!).toSet();
      if (matches.length == 1) return matches.single.trim();
    }
    return null;
  }

  /// "16GB" => số bất kỳ + "GB" (cho phép dấu cách giữa số và chữ).
  static RegExp _valuePattern(String value) {
    final buffer = StringBuffer(r'(?<![\p{L}\d])');
    final parts = RegExp(
      r'\d+(?:[.,]\d+)?|\s+|[^\d\s]+',
    ).allMatches(value.trim());
    var previousDigit = false;
    for (final m in parts) {
      final part = m[0]!;
      final isDigit = RegExp(r'^\d').hasMatch(part);
      if (part.trim().isEmpty) {
        buffer.write(r'\s*');
      } else if (isDigit) {
        buffer.write(r'\d+(?:[.,]\d+)?');
      } else {
        if (previousDigit) buffer.write(r'\s*');
        buffer.write(RegExp.escape(part));
      }
      previousDigit = isDigit;
    }
    buffer.write(r'(?![\p{L}\d])');
    return RegExp(buffer.toString(), caseSensitive: false, unicode: true);
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
      _db.get<ComboPart>().removeMany(undo.comboPartIds);
      optionBox.removeMany(undo.optionIds);
      variantBox.removeMany(undo.variantIds);
      componentBox.removeMany(undo.componentIds);
      _db.get<Shop>().removeMany(undo.shopIds);
    });
  }
}

/// Trạng thái màn xem trước nhập: các dòng cùng sản phẩm / cùng linh kiện
/// biết nhau để chỉ cần tạo linh kiện / biến thể mới 1 lần.
class ImportSession {
  final List<ImportPlan> plans;

  ImportSession(this.plans);

  /// Linh kiện đích của dòng: có sẵn theo id, tạo mới theo tên.
  static String targetKey(ImportPlan p) => p.existing != null
      ? "#${p.existing!.id}"
      : "new:${p.name.trim().toLowerCase()}";

  static bool _sameText(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Các dòng cùng sản phẩm (cùng tên gốc, VD các phân loại của 1 sản phẩm
  /// Shopee), gồm cả [p].
  List<ImportPlan> sameProduct(ImportPlan p) =>
      plans.where((q) => _sameText(q.row.name, p.row.name)).toList();

  List<ImportPlan> sameTarget(ImportPlan p) {
    final key = targetKey(p);
    return plans.where((q) => targetKey(q) == key).toList();
  }

  /// Tên các linh kiện sẽ tạo mới (để chọn ở dòng khác).
  List<String> newNames() {
    final seen = <String>{};
    return [
      for (final p in plans)
        if (p.existing == null && seen.add(p.name.trim().toLowerCase()))
          p.name.trim(),
    ];
  }

  /// Thuộc tính của linh kiện đích: có sẵn => theo linh kiện; tạo mới => gộp
  /// từ các dòng cùng tên.
  List<String> attributeNames(ImportPlan p) {
    if (p.existing case final c?) return [for (final a in c.attributes) a.name];
    final names = <String>[];
    for (final s in [
      for (final q in sameTarget(p)) q.attributes,
      for (final d in comboDrafts(targetKey(p))) d.selection,
    ]) {
      for (final name in s.keys) {
        if (!names.any((n) => _sameText(n, name))) names.add(name);
      }
    }
    return names;
  }

  /// Biến thể mới (chưa có) mà các combo trong lần nhập dùng cho linh kiện
  /// đích [key].
  List<ImportComboPart> comboDrafts(String key) => [
    for (final q in plans)
      for (final d in q.comboExtras)
        if (d.isDraft && d.targetKey == key) d,
  ];

  /// Biến thể sẽ tạo trong lần nhập (của mọi linh kiện đích) để chọn làm
  /// thành phần combo; linh kiện mới không thuộc tính => biến thể mặc định.
  List<ImportComboPart> comboChoices() {
    final seen = <String>{};
    final result = <ImportComboPart>[];
    for (final p in plans) {
      if (!seen.add(targetKey(p))) continue;
      final pending = pendingVariants(p);
      if (p.existing == null && attributeNames(p).isEmpty) {
        result.add(ImportComboPart.draft(newName: p.name.trim()));
      }
      for (final s in pending) {
        result.add(
          ImportComboPart.draft(
            component: p.existing,
            newName: p.existing == null ? p.name.trim() : "",
            selection: s,
          ),
        );
      }
    }
    return result;
  }

  /// Giá trị đã biết của từng thuộc tính (có sẵn + các dòng cùng linh kiện).
  Map<String, List<String>> knownValues(ImportPlan p) {
    final result = <String, Set<String>>{};
    for (final a in p.existing?.attributes ?? const <VariantAttribute>[]) {
      result.putIfAbsent(a.name, () => {}).addAll(a.values);
    }
    for (final name in attributeNames(p)) {
      final values = result.putIfAbsent(name, () => {});
      for (final q in sameTarget(p)) {
        if (_attr(q.attributes, name) case final v?) values.add(v);
      }
      for (final d in comboDrafts(targetKey(p))) {
        if (_attr(d.selection, name) case final v?) values.add(v);
      }
    }
    return {
      for (final e in result.entries) e.key: Variants.sortValues(e.value),
    };
  }

  static String? _attr(VariantSelection s, String name) =>
      s.entries.where((e) => _sameText(e.key, name)).firstOrNull?.value;

  /// Dòng đã đủ giá trị cho mọi thuộc tính của linh kiện đích.
  bool covers(ImportPlan p, [List<String>? names]) {
    final all = names ?? attributeNames(p);
    return all.isNotEmpty && all.every((n) => _attr(p.attributes, n) != null);
  }

  /// Lựa chọn của dòng theo đúng tên thuộc tính của linh kiện đích.
  VariantSelection normalized(ImportPlan p) => {
    for (final n in attributeNames(p)) n: ?_attr(p.attributes, n),
  };

  /// Biến thể chưa có, sẽ được tạo theo các dòng cùng linh kiện.
  List<VariantSelection> pendingVariants(ImportPlan p) {
    final names = attributeNames(p);
    final existing = {
      for (final v in p.existing?.variants ?? const <ComponentVariant>[])
        Variants.key(v.selection),
    };
    final result = <String, VariantSelection>{};
    for (final q in sameTarget(p)) {
      if (q.variantId != null || !covers(q, names)) continue;
      final s = normalized(q);
      final key = Variants.key(s);
      if (!existing.contains(key)) result.putIfAbsent(key, () => s);
    }
    // Biến thể mới chỉ dùng trong combo (VD đầu cái XT60)
    for (final d in comboDrafts(targetKey(p))) {
      if (names.isEmpty || !names.every((n) => _attr(d.selection, n) != null)) {
        continue;
      }
      final s = {for (final n in names) n: _attr(d.selection, n)!};
      final key = Variants.key(s);
      if (!existing.contains(key)) result.putIfAbsent(key, () => s);
    }
    final list = result.values.toList()
      ..sort((a, b) {
        for (final n in names) {
          final c = Variants.compareValues(a[n] ?? "", b[n] ?? "");
          if (c != 0) return c;
        }
        return 0;
      });
    return list;
  }

  /// Dòng đủ thuộc tính mà trùng biến thể có sẵn => chọn luôn biến thể đó.
  void _resolveVariant(ImportPlan q) {
    final c = q.existing;
    if (c == null || q.variantId != null || !covers(q)) return;
    final key = Variants.key(normalized(q));
    final match = c.variants.where((v) => Variants.key(v.selection) == key);
    if (match.isNotEmpty) q.variantId = match.first.id;
  }

  /// Đổi danh mục / loại / icon cho linh kiện mới của [p]: mọi dòng sẽ gộp
  /// vào cùng linh kiện đó (cùng tên) đổi theo.
  void setNewDetails(
    ImportPlan p, {
    int? categoryId,
    int? typeId,
    String? iconSvg,
  }) {
    if (p.existing != null) return;
    for (final q in sameTarget(p)) {
      if (categoryId != null) q.categoryId = categoryId;
      if (typeId != null) q.typeId = typeId;
      if (iconSvg != null) q.iconSvg = iconSvg;
    }
  }

  /// Chọn linh kiện có sẵn ([component]) hoặc tạo mới (null, tên [newName]
  /// hoặc tên gốc của dòng) cho [p], kèm các dòng cùng sản phẩm nếu
  /// [sameProduct]. Trả về số dòng đã đổi (gồm [p]).
  int setTarget(
    ImportPlan p,
    Component? component, {
    String? newName,
    bool sameProduct = true,
  }) {
    final rows = sameProduct ? this.sameProduct(p) : [p];
    for (final q in rows) {
      if (component == null) {
        q.createNew();
        if (newName != null && newName.trim().isNotEmpty) {
          q.name = newName.trim();
        }
      } else if (component.id == q.suggested?.id) {
        q.useSuggestion();
      } else {
        q.selectComponent(component);
      }
    }
    return rows.length;
  }

  /// Quay về gợi ý ban đầu cho [p], kèm các dòng cùng sản phẩm nếu
  /// [sameProduct].
  int useSuggestion(ImportPlan p, {bool sameProduct = true}) {
    final rows = sameProduct ? this.sameProduct(p) : [p];
    for (final q in rows) {
      q.useSuggestion();
    }
    return rows.length;
  }

  void chooseVariant(ImportPlan p, int variantId) {
    p.variantId = variantId;
    p.attributes = p.row.attributes;
  }

  void choosePending(ImportPlan p, VariantSelection selection) {
    p.variantId = null;
    p.attributes = selection;
  }

  /// Biến thể mới cho [p] rồi đoán giá trị cho các dòng cùng linh kiện còn
  /// thiếu, theo cách đã điền ở [p] (xem [ImportService.inferSelection]).
  /// Trả về số dòng khác được điền thêm.
  int setVariant(ImportPlan p, VariantSelection selection) {
    p.variantId = null;
    p.attributes = {...p.attributes, ...selection};
    // Bỏ khoá trùng khác hoa thường (giữ cách viết mới)
    for (final name in selection.keys) {
      p.attributes.removeWhere((k, _) => k != name && _sameText(k, name));
    }
    _resolveVariant(p);

    final names = attributeNames(p);
    var filled = 0;
    for (final q in sameTarget(p)) {
      if (identical(q, p) || q.variantId != null || covers(q, names)) continue;
      final missing = {
        for (final e in selection.entries)
          if (_attr(q.attributes, e.key) == null) e.key: e.value,
      };
      final inferred = ImportService.inferSelection(p.row, missing, q.row);
      if (inferred == null) continue;
      q.attributes = {...q.attributes, ...inferred};
      _resolveVariant(q);
      if (covers(q, names)) filled++;
    }
    return filled;
  }
}
