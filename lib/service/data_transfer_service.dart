import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/app_setting.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/combo_part.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/ai/ai_settings.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/project_group_migration.dart';
import 'package:component_companion/service/variant_migration.dart';

/// Ảnh chụp dữ liệu dạng JSON-friendly map: tên bảng -> danh sách bản ghi.
/// Mỗi bản ghi giữ id cũ và id quan hệ cũ; khi ghi lại sẽ được ánh xạ id mới.
typedef DataSnapshot = Map<String, dynamic>;

/// Xuất / nhập dữ liệu dùng cho: sao lưu - khôi phục và hoàn tác khi xoá.
///
/// Phiên bản định dạng:
/// - 1: tuỳ chọn áp dụng theo thuộc tính, tồn kho theo linh kiện, shop là chuỗi
/// - 2: biến thể ([ComponentVariant]), bảng [Shop], tuỳ chọn gắn nhiều biến thể
/// - 3: nhóm lựa chọn của dự án ([ProjectGroup]), thư viện icon ([IconAsset])
/// - 4: nhật ký kho ([StockLog]), số "đang về" của biến thể
/// - 5: tuỳ chọn mua dạng combo ([ComboPart])
/// - 6: kho thông minh ([TrayType], [PowerSupply], [Storage], [StorageTray]),
///   chỗ cất của biến thể
/// - 7: vách ngăn tháo được ([TrayType.removableDividers],
///   [StorageTray.removedDividers])
/// - 8: màu báo ngăn ([TrayType.compartmentColorsJson])
///
/// File v1 vẫn khôi phục được: dữ liệu được ghi vào các trường cũ rồi chạy
/// [VariantMigration] để chuyển sang mô hình mới. File v1, v2 chưa có nhóm lựa
/// chọn => [ProjectGroupMigration] gom các phiên bản vào nhóm.
class DataTransferService {
  static const format = "component-companion-backup";
  static const version = 8;

  static const _tables = [
    "categories",
    "types",
    "shops",
    "trayTypes",
    "powerSupplies",
    "storages",
    "storageTrays",
    "components",
    "variants",
    "options",
    "comboParts",
    "priceRecords",
    "stockItems",
    "projects",
    "projectGroups",
    "projectOptions",
    "projectItems",
    "icons",
    "stockLogs",
    "settings",
  ];

  final _db = ObjectboxService.instance;

  // ---------------------------------------------------------------------------
  // XUẤT
  // ---------------------------------------------------------------------------

  /// Toàn bộ dữ liệu.
  DataSnapshot exportAll() => _build(
    categories: _db.get<Category>().getAll(),
    types: _db.get<ComponentType>().getAll(),
    shops: _db.get<Shop>().getAll(),
    trayTypes: _db.get<TrayType>().getAll(),
    powerSupplies: _db.get<PowerSupply>().getAll(),
    storages: _db.get<Storage>().getAll(),
    storageTrays: _db.get<StorageTray>().getAll(),
    components: _db.get<Component>().getAll(),
    variants: _db.get<ComponentVariant>().getAll(),
    options: _db.get<ComponentOption>().getAll(),
    comboParts: _db.get<ComboPart>().getAll(),
    priceRecords: _db.get<PriceRecord>().getAll(),
    projects: _db.get<Project>().getAll(),
    projectGroups: _db.get<ProjectGroup>().getAll(),
    projectOptions: _db.get<ProjectOption>().getAll(),
    projectItems: _db.get<ProjectItem>().getAll(),
    icons: _db.get<IconAsset>().getAll(),
    stockLogs: _db.get<StockLog>().getAll(),
    // API key... chỉ ở máy này, không vào file sao lưu
    settings: _db
        .get<AppSetting>()
        .getAll()
        .where((s) => !AiSettings.secretKeys.contains(s.key))
        .toList(),
  );

  /// Ảnh chụp các bản ghi sắp bị xoá (kèm dữ liệu phụ thuộc bị xoá theo) để hoàn tác.
  DataSnapshot snapshot({
    List<int> categoryIds = const [],
    List<int> typeIds = const [],
    List<int> shopIds = const [],
    List<int> componentIds = const [],
    List<int> variantIds = const [],
    List<int> optionIds = const [],
    List<int> projectIds = const [],
    List<int> projectGroupIds = const [],
    List<int> projectOptionIds = const [],
    List<int> projectItemIds = const [],
    List<int> iconIds = const [],
    List<int> storageIds = const [],
    List<int> storageTrayIds = const [],
  }) {
    final optionBox = _db.get<ComponentOption>();
    final itemBox = _db.get<ProjectItem>();
    final projectOptionBox = _db.get<ProjectOption>();

    // Linh kiện bị xoá kéo theo biến thể + tuỳ chọn
    final allVariantIds = {
      ...variantIds,
      ..._db
          .get<ComponentVariant>()
          .query(ComponentVariant_.component.anyOf(componentIds))
          .getIdsAndClose(),
    }.toList();
    final allOptionIds = {
      ...optionIds,
      ...optionBox
          .query(ComponentOption_.component.anyOf(componentIds))
          .getIdsAndClose(),
    }.toList();

    // Dự án bị xoá kéo theo nhóm, phương án + linh kiện trong dự án
    final allProjectGroupIds = {
      ...projectGroupIds,
      ..._db
          .get<ProjectGroup>()
          .query(ProjectGroup_.project.anyOf(projectIds))
          .getIdsAndClose(),
    }.toList();
    final allProjectOptionIds = {
      ...projectOptionIds,
      ...projectOptionBox
          .query(ProjectOption_.project.anyOf(projectIds))
          .getIdsAndClose(),
      ...projectOptionBox
          .query(ProjectOption_.group.anyOf(allProjectGroupIds))
          .getIdsAndClose(),
    }.toList();
    final allItemIds = {
      ...projectItemIds,
      ...itemBox.query(ProjectItem_.project.anyOf(projectIds)).getIdsAndClose(),
      ...itemBox
          .query(ProjectItem_.projectOption.anyOf(allProjectOptionIds))
          .getIdsAndClose(),
    }.toList();

    // Kho bị xoá kéo theo các khay
    final allTrayIds = {
      ...storageTrayIds,
      ..._db
          .get<StorageTray>()
          .query(StorageTray_.storage.anyOf(storageIds))
          .getIdsAndClose(),
    }.toList();

    List<T> many<T>(List<int> ids) =>
        _db.get<T>().getMany(ids).whereType<T>().toList();

    final data = _build(
      categories: many<Category>(categoryIds),
      types: many<ComponentType>(typeIds),
      shops: many<Shop>(shopIds),
      trayTypes: const [],
      powerSupplies: const [],
      storages: many<Storage>(storageIds),
      storageTrays: many<StorageTray>(allTrayIds),
      components: many<Component>(componentIds),
      variants: many<ComponentVariant>(allVariantIds),
      options: many<ComponentOption>(allOptionIds),
      comboParts: _db
          .get<ComboPart>()
          .query(ComboPart_.option.anyOf(allOptionIds))
          .findAndClose(),
      priceRecords: _db
          .get<PriceRecord>()
          .query(PriceRecord_.option.anyOf(allOptionIds))
          .findAndClose(),
      projects: many<Project>(projectIds),
      projectGroups: many<ProjectGroup>(allProjectGroupIds),
      projectOptions: many<ProjectOption>(allProjectOptionIds),
      projectItems: many<ProjectItem>(allItemIds),
      icons: many<IconAsset>(iconIds),
      stockLogs: const [],
      settings: const [],
    );
    // Khi xoá, ObjectBox gỡ liên kết của bản ghi bên ngoài (backlink) nên phải
    // ghi lại NGAY BÂY GIỜ những bản ghi nào đang trỏ tới dữ liệu sắp xoá
    data["outside"] = _collectOutside(data);
    return data;
  }

  DataSnapshot _build({
    required List<Category> categories,
    required List<ComponentType> types,
    required List<Shop> shops,
    required List<TrayType> trayTypes,
    required List<PowerSupply> powerSupplies,
    required List<Storage> storages,
    required List<StorageTray> storageTrays,
    required List<Component> components,
    required List<ComponentVariant> variants,
    required List<ComponentOption> options,
    required List<ComboPart> comboParts,
    required List<PriceRecord> priceRecords,
    required List<Project> projects,
    required List<ProjectGroup> projectGroups,
    required List<ProjectOption> projectOptions,
    required List<ProjectItem> projectItems,
    required List<IconAsset> icons,
    required List<StockLog> stockLogs,
    required List<AppSetting> settings,
  }) => {
    "format": format,
    "version": version,
    "createdAt": DateTime.now().toIso8601String(),
    "categories": [
      for (final c in categories)
        {
          "id": c.id,
          "name": c.name,
          "description": c.description,
          "colorValue": c.colorValue,
          "iconSvg": c.iconSvg,
          "keywords": c.keywords,
        },
    ],
    "types": [
      for (final t in types)
        {
          "id": t.id,
          "name": t.name,
          "defaultIconSvg": t.defaultIconSvg,
          "keywords": t.keywords,
          "attributeTemplate": t.attributeTemplate,
          "categoryId": t.category.targetId,
        },
    ],
    "shops": [
      for (final s in shops)
        {"id": s.id, "name": s.name, "link": s.link, "note": s.note},
    ],
    "trayTypes": [
      for (final t in trayTypes)
        {
          "id": t.id,
          "name": t.name,
          "widthMm": t.widthMm,
          "depthMm": t.depthMm,
          "heightMm": t.heightMm,
          "stackGapMm": t.stackGapMm,
          "compartmentCount": t.compartmentCount,
          "compartmentVertical": t.compartmentVertical,
          "removableDividers": t.removableDividers,
          "allowedColorsJson": t.allowedColorsJson,
          "defaultColor": t.defaultColor,
          "compartmentColorsJson": t.compartmentColorsJson,
          "minBrightness": t.minBrightness,
          "maxBrightness": t.maxBrightness,
          "note": t.note,
        },
    ],
    "powerSupplies": [
      for (final p in powerSupplies)
        {
          "id": p.id,
          "name": p.name,
          "voltage": p.voltage,
          "currentA": p.currentA,
          "derate": p.derate,
          "note": p.note,
        },
    ],
    "storages": [
      for (final s in storages)
        {
          "id": s.id,
          "name": s.name,
          "widthMm": s.widthMm,
          "heightMm": s.heightMm,
          "gridMm": s.gridMm,
          "ledCount": s.ledCount,
          "colorOrder": s.colorOrder,
          "mAPerChannel": s.mAPerChannel,
          "idleMaPerLed": s.idleMaPerLed,
          "mcuMa": s.mcuMa,
          "lightTimeoutS": s.lightTimeoutS,
          "bleDeviceId": s.bleDeviceId,
          "bleName": s.bleName,
          "note": s.note,
          "powerSupplyId": s.powerSupply.targetId,
        },
    ],
    "storageTrays": [
      for (final t in storageTrays)
        {
          "id": t.id,
          "storageId": t.storage.targetId,
          "trayTypeId": t.trayType.targetId,
          "xMm": t.xMm,
          "yMm": t.yMm,
          "rotated": t.rotated,
          "label": t.label,
          "ledIndex": t.ledIndex,
          "removedDividers": t.removedDividers,
        },
    ],
    "components": [
      for (final c in components)
        {
          "id": c.id,
          "name": c.name,
          "description": c.description,
          "base64Image": c.base64Image,
          "iconSvg": c.iconSvg,
          "attributesJson": c.attributesJson,
          "lowStockThreshold": c.lowStockThreshold,
          "categoryId": c.category.targetId,
          "typeId": c.type.targetId,
        },
    ],
    "variants": [
      for (final v in variants)
        {
          "id": v.id,
          "componentId": v.component.targetId,
          "selectionJson": v.selectionJson,
          "stock": v.stock,
          "incoming": v.incoming,
          "location": v.location,
          "lowStockThreshold": v.lowStockThreshold,
          "note": v.note,
          "trayId": v.tray.targetId,
          "compartmentIndex": v.compartmentIndex,
        },
    ],
    "options": [
      for (final o in options)
        {
          "id": o.id,
          "componentId": o.component.targetId,
          "shopId": o.shop.targetId,
          "variantIds": o.variants.map((v) => v.id).toList(),
          "name": o.name,
          "unitsPerPack": o.unitsPerPack,
          "pricePerPack": o.pricePerPack,
          "link": o.link,
          "priceCheckedAt": o.priceCheckedAt?.millisecondsSinceEpoch,
        },
    ],
    "comboParts": [
      for (final p in comboParts)
        {
          "id": p.id,
          "optionId": p.option.targetId,
          "variantId": p.variant.targetId,
          "quantity": p.quantity,
        },
    ],
    "priceRecords": [
      for (final r in priceRecords)
        {
          "id": r.id,
          "optionId": r.option.targetId,
          "pricePerPack": r.pricePerPack,
          "unitsPerPack": r.unitsPerPack,
          "recordedAt": r.recordedAt.millisecondsSinceEpoch,
        },
    ],
    "projects": [
      for (final p in projects)
        {
          "id": p.id,
          "name": p.name,
          "description": p.description,
          "base64Image": p.base64Image,
          "updatedAt": p.updatedAt,
          "status": p.status,
        },
    ],
    "projectGroups": [
      for (final g in projectGroups)
        {
          "id": g.id,
          "projectId": g.project.targetId,
          "name": g.name,
          "sortOrder": g.sortOrder,
          "selectedOptionId": g.selected.targetId,
        },
    ],
    "projectOptions": [
      for (final o in projectOptions)
        {
          "id": o.id,
          "projectId": o.project.targetId,
          "groupId": o.group.targetId,
          "name": o.name,
          "description": o.description,
        },
    ],
    "projectItems": [
      for (final i in projectItems)
        {
          "id": i.id,
          "quantity": i.quantity,
          "componentId": i.component.targetId,
          "variantId": i.variant.targetId,
          "componentOptionId": i.componentOption.targetId,
          "projectOptionId": i.projectOption.targetId,
          "projectId": i.project.targetId,
        },
    ],
    "icons": [
      for (final i in icons)
        {
          "id": i.id,
          "name": i.name,
          "pack": i.pack,
          "svg": i.svg,
          "keywords": i.keywords,
        },
    ],
    "stockLogs": [
      for (final l in stockLogs)
        {
          "id": l.id,
          "variantId": l.variant.targetId,
          "projectId": l.project.targetId,
          "before": l.before,
          "after": l.after,
          "reason": l.reason,
          "note": l.note,
          "marked": l.marked,
          "label": l.label,
          "at": l.at.millisecondsSinceEpoch,
        },
    ],
    "settings": [
      for (final s in settings) {"key": s.key, "value": s.value},
    ],
  };

  // ---------------------------------------------------------------------------
  // NHẬP
  // ---------------------------------------------------------------------------

  /// Kiểm tra file sao lưu hợp lệ, trả về thông báo lỗi hoặc null.
  static String? validate(Object? data) {
    if (data is! Map<String, dynamic>) return "File không đúng định dạng JSON";
    if (data["format"] != format) {
      return "Đây không phải file sao lưu của Component Companion";
    }
    final v = data["version"];
    if (v is! int || v > version) {
      return "File sao lưu được tạo bởi phiên bản mới hơn, hãy cập nhật ứng dụng";
    }
    return null;
  }

  /// Thống kê số bản ghi theo bảng (hiển thị trước khi khôi phục).
  static Map<String, int> countOf(DataSnapshot data) => {
    for (final table in _tables) table: (data[table] as List?)?.length ?? 0,
  };

  /// XOÁ TOÀN BỘ dữ liệu hiện tại rồi ghi dữ liệu từ [data].
  void replaceAll(DataSnapshot data) {
    _db.store.runInTransaction(TxMode.write, () {
      // Giữ cài đặt bí mật của máy này (file sao lưu không có)
      final secrets = _db
          .get<AppSetting>()
          .getAll()
          .where((s) => AiSettings.secretKeys.contains(s.key))
          .toList();
      _db.get<ProjectItem>().removeAll();
      _db.get<ProjectOption>().removeAll();
      _db.get<ProjectGroup>().removeAll();
      _db.get<Project>().removeAll();
      _db.get<StockItem>().removeAll();
      _db.get<PriceRecord>().removeAll();
      _db.get<ComboPart>().removeAll();
      _db.get<ComponentOption>().removeAll();
      _db.get<ComponentVariant>().removeAll();
      _db.get<Component>().removeAll();
      _db.get<Shop>().removeAll();
      _db.get<StorageTray>().removeAll();
      _db.get<Storage>().removeAll();
      _db.get<TrayType>().removeAll();
      _db.get<PowerSupply>().removeAll();
      _db.get<ComponentType>().removeAll();
      _db.get<Category>().removeAll();
      _db.get<IconAsset>().removeAll();
      _db.get<StockLog>().removeAll();
      _db.get<AppSetting>().removeAll();
      _insert(data, relinkOutside: false);
      for (final s in secrets) {
        _db.get<AppSetting>().put(AppSetting(key: s.key, value: s.value));
      }

      // File định dạng cũ => chuyển sang mô hình mới ngay
      final fileVersion = (data["version"] as int?) ?? 1;
      if (fileVersion < 2) VariantMigration().run();
      if (fileVersion < 3) ProjectGroupMigration().run();
    });
  }

  /// Ghi thêm dữ liệu [data] (dùng để hoàn tác xoá). Các bản ghi bên ngoài
  /// đang trỏ tới id cũ (VD linh kiện trong dự án) được nối lại sang id mới.
  void restore(DataSnapshot data) {
    _db.store.runInTransaction(
      TxMode.write,
      () => _insert(data, relinkOutside: true),
    );
  }

  void _insert(DataSnapshot data, {required bool relinkOutside}) {
    List<Map<String, dynamic>> rows(String table) =>
        ((data[table] as List?) ?? const []).cast<Map<String, dynamic>>();

    // old id -> new id theo từng bảng
    final ids = <String, Map<int, int>>{for (final t in _tables) t: {}};
    int map(String table, Object? oldId) {
      final id = (oldId as int?) ?? 0;
      return id == 0 ? 0 : (ids[table]![id] ?? id);
    }

    final outside = relinkOutside
        ? (data["outside"] as Map<String, dynamic>?)
        : null;

    final categoryBox = _db.get<Category>();
    for (final r in rows("categories")) {
      ids["categories"]![r["id"] as int] = categoryBox.put(
        Category(
          name: r["name"] as String,
          description: r["description"] as String? ?? "",
          colorValue: r["colorValue"] as int,
          iconSvg: r["iconSvg"] as String? ?? "",
          keywords: (r["keywords"] as List? ?? const []).cast<String>(),
        ),
      );
    }

    final typeBox = _db.get<ComponentType>();
    for (final r in rows("types")) {
      ids["types"]![r["id"] as int] = typeBox.put(
        ComponentType(
          name: r["name"] as String,
          defaultIconSvg: r["defaultIconSvg"] as String? ?? "",
          keywords: (r["keywords"] as List? ?? const []).cast<String>(),
          attributeTemplate: (r["attributeTemplate"] as List? ?? const [])
              .cast<String>(),
        )..category.targetId = map("categories", r["categoryId"]),
      );
    }

    final shopBox = _db.get<Shop>();
    for (final r in rows("shops")) {
      ids["shops"]![r["id"] as int] = shopBox.put(
        Shop(
          name: r["name"] as String,
          link: r["link"] as String? ?? "",
          note: r["note"] as String? ?? "",
        ),
      );
    }

    double dbl(Object? v, double fallback) =>
        (v as num?)?.toDouble() ?? fallback;

    final trayTypeBox = _db.get<TrayType>();
    for (final r in rows("trayTypes")) {
      ids["trayTypes"]![r["id"] as int] = trayTypeBox.put(
        TrayType(
          name: r["name"] as String,
          widthMm: dbl(r["widthMm"], 100),
          depthMm: dbl(r["depthMm"], 100),
          heightMm: dbl(r["heightMm"], 50),
          stackGapMm: dbl(r["stackGapMm"], 0),
          compartmentCount: r["compartmentCount"] as int? ?? 1,
          compartmentVertical: r["compartmentVertical"] as bool? ?? false,
          removableDividers: r["removableDividers"] as bool? ?? false,
          allowedColorsJson: r["allowedColorsJson"] as String? ?? "",
          defaultColor: r["defaultColor"] as int? ?? 0xFF2196F3,
          compartmentColorsJson: r["compartmentColorsJson"] as String? ?? "",
          minBrightness: r["minBrightness"] as int? ?? 40,
          maxBrightness: r["maxBrightness"] as int? ?? 255,
          note: r["note"] as String? ?? "",
        ),
      );
    }

    final supplyBox = _db.get<PowerSupply>();
    for (final r in rows("powerSupplies")) {
      ids["powerSupplies"]![r["id"] as int] = supplyBox.put(
        PowerSupply(
          name: r["name"] as String,
          voltage: dbl(r["voltage"], 5),
          currentA: dbl(r["currentA"], 2),
          derate: dbl(r["derate"], 0.8),
          note: r["note"] as String? ?? "",
        ),
      );
    }

    final storageBox = _db.get<Storage>();
    for (final r in rows("storages")) {
      ids["storages"]![r["id"] as int] = storageBox.put(
        Storage(
          name: r["name"] as String,
          widthMm: dbl(r["widthMm"], 1000),
          heightMm: dbl(r["heightMm"], 800),
          gridMm: dbl(r["gridMm"], 10),
          ledCount: r["ledCount"] as int? ?? 60,
          colorOrder: r["colorOrder"] as String? ?? "GRB",
          mAPerChannel: dbl(r["mAPerChannel"], 20),
          idleMaPerLed: dbl(r["idleMaPerLed"], 0.6),
          mcuMa: dbl(r["mcuMa"], 120),
          lightTimeoutS: r["lightTimeoutS"] as int? ?? 60,
          bleDeviceId: r["bleDeviceId"] as String? ?? "",
          bleName: r["bleName"] as String? ?? "",
          note: r["note"] as String? ?? "",
        )..powerSupply.targetId = map("powerSupplies", r["powerSupplyId"]),
      );
    }

    final storageTrayBox = _db.get<StorageTray>();
    for (final r in rows("storageTrays")) {
      ids["storageTrays"]![r["id"] as int] = storageTrayBox.put(
        StorageTray(
            xMm: dbl(r["xMm"], 0),
            yMm: dbl(r["yMm"], 0),
            rotated: r["rotated"] as bool? ?? false,
            label: r["label"] as String? ?? "",
            ledIndex: r["ledIndex"] as int? ?? -1,
            removedDividers: r["removedDividers"] as int? ?? 0,
          )
          ..storage.targetId = map("storages", r["storageId"])
          ..trayType.targetId = map("trayTypes", r["trayTypeId"]),
      );
    }

    final componentBox = _db.get<Component>();
    for (final r in rows("components")) {
      ids["components"]![r["id"] as int] = componentBox.put(
        Component(
            name: r["name"] as String,
            description: r["description"] as String? ?? "",
            base64Image: r["base64Image"] as String? ?? "",
            iconSvg: r["iconSvg"] as String? ?? "",
            attributesJson: r["attributesJson"] as String? ?? "",
            lowStockThreshold: r["lowStockThreshold"] as int? ?? 0,
          )
          ..category.targetId = map("categories", r["categoryId"])
          ..type.targetId = map("types", r["typeId"]),
      );
    }

    final variantBox = _db.get<ComponentVariant>();
    for (final r in rows("variants")) {
      ids["variants"]![r["id"] as int] = variantBox.put(
        ComponentVariant(
            selectionJson: r["selectionJson"] as String? ?? "",
            stock: r["stock"] as int?,
            incoming: r["incoming"] as int? ?? 0,
            location: r["location"] as String? ?? "",
            lowStockThreshold: r["lowStockThreshold"] as int? ?? 0,
            note: r["note"] as String? ?? "",
            compartmentIndex: r["compartmentIndex"] as int? ?? 0,
          )
          ..component.targetId = map("components", r["componentId"])
          ..tray.targetId = map("storageTrays", r["trayId"]),
      );
    }

    final optionBox = _db.get<ComponentOption>();
    for (final r in rows("options")) {
      final checkedAt = r["priceCheckedAt"] as int?;
      final option =
          ComponentOption(
              name: r["name"] as String,
              unitsPerPack: r["unitsPerPack"] as int? ?? 1,
              pricePerPack: r["pricePerPack"] as int? ?? 0,
              link: r["link"] as String? ?? "",
              // Định dạng v1
              legacyShopName: r["shop"] as String? ?? "",
              legacyAvailabilityJson: r["availabilityJson"] as String? ?? "",
              priceCheckedAt: checkedAt == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(checkedAt),
            )
            ..component.targetId = map("components", r["componentId"])
            ..shop.targetId = map("shops", r["shopId"]);
      for (final variantId in (r["variantIds"] as List? ?? const [])) {
        final id = map("variants", variantId);
        final variant = variantBox.get(id);
        if (variant != null) option.variants.add(variant);
      }
      ids["options"]![r["id"] as int] = optionBox.put(option);
    }

    _db.get<ComboPart>().putMany([
      for (final r in rows("comboParts"))
        ComboPart(quantity: r["quantity"] as int? ?? 1)
          ..option.targetId = map("options", r["optionId"])
          ..variant.targetId = map("variants", r["variantId"]),
    ]);

    _db.get<PriceRecord>().putMany([
      for (final r in rows("priceRecords"))
        PriceRecord(
          pricePerPack: r["pricePerPack"] as int? ?? 0,
          unitsPerPack: r["unitsPerPack"] as int? ?? 1,
          recordedAt: DateTime.fromMillisecondsSinceEpoch(
            r["recordedAt"] as int,
          ),
        )..option.targetId = map("options", r["optionId"]),
    ]);

    // Định dạng v1: tồn kho theo linh kiện (VariantMigration sẽ chuyển)
    _db.get<StockItem>().putMany([
      for (final r in rows("stockItems"))
        StockItem(
          quantity: r["quantity"] as int? ?? 0,
          location: r["location"] as String? ?? "",
          variantJson: r["variantJson"] as String? ?? "",
        )..component.targetId = map("components", r["componentId"]),
    ]);

    final projectBox = _db.get<Project>();
    for (final r in rows("projects")) {
      ids["projects"]![r["id"] as int] = projectBox.put(
        Project(
          name: r["name"] as String,
          description: r["description"] as String? ?? "",
          base64Image: r["base64Image"] as String? ?? "",
          updatedAt: r["updatedAt"] as int? ?? 0,
          status: r["status"] as String? ?? "",
        ),
      );
    }

    final groupBox = _db.get<ProjectGroup>();
    final groupRows = rows("projectGroups");
    for (final r in groupRows) {
      ids["projectGroups"]![r["id"] as int] = groupBox.put(
        ProjectGroup(
          name: r["name"] as String,
          sortOrder: r["sortOrder"] as int? ?? 0,
        )..project.targetId = map("projects", r["projectId"]),
      );
    }

    final projectOptionBox = _db.get<ProjectOption>();
    for (final r in rows("projectOptions")) {
      ids["projectOptions"]![r["id"] as int] = projectOptionBox.put(
        ProjectOption(
            name: r["name"] as String,
            description: r["description"] as String? ?? "",
          )
          ..project.targetId = map("projects", r["projectId"])
          ..group.targetId = map("projectGroups", r["groupId"]),
      );
    }

    // Phương án đang chọn chỉ có id mới sau khi ghi phương án
    for (final r in groupRows) {
      final group = groupBox.get(map("projectGroups", r["id"]));
      if (group == null) continue;
      group.selected.targetId = map("projectOptions", r["selectedOptionId"]);
      groupBox.put(group);
    }

    _db.get<ProjectItem>().putMany([
      for (final r in rows("projectItems"))
        ProjectItem(
            quantity: r["quantity"] as int? ?? 1,
            // Định dạng v1
            legacyVariantJson: r["variantJson"] as String? ?? "",
          )
          ..component.targetId = map("components", r["componentId"])
          ..variant.targetId = map("variants", r["variantId"])
          ..componentOption.targetId = map("options", r["componentOptionId"])
          ..projectOption.targetId = map("projectOptions", r["projectOptionId"])
          ..project.targetId = map("projects", r["projectId"]),
    ]);

    _db.get<IconAsset>().putMany([
      for (final r in rows("icons"))
        IconAsset(
          name: r["name"] as String,
          pack: r["pack"] as String? ?? "",
          svg: r["svg"] as String? ?? "",
          keywords: (r["keywords"] as List? ?? const []).cast<String>(),
        ),
    ]);

    _db.get<StockLog>().putMany([
      for (final r in rows("stockLogs"))
        StockLog(
            before: r["before"] as int?,
            after: r["after"] as int?,
            reason: r["reason"] as String? ?? "",
            note: r["note"] as String? ?? "",
            marked: r["marked"] as int? ?? 0,
            label: r["label"] as String? ?? "",
            at: DateTime.fromMillisecondsSinceEpoch(r["at"] as int),
          )
          ..variant.targetId = map("variants", r["variantId"])
          ..project.targetId = map("projects", r["projectId"]),
    ]);

    final settingBox = _db.get<AppSetting>();
    for (final r in rows("settings")) {
      settingBox.put(
        AppSetting(key: r["key"] as String, value: r["value"] as String),
      );
    }

    if (outside != null) _relinkOutside(outside, ids);
  }

  /// Các bản ghi không nằm trong [data] nhưng đang trỏ tới bản ghi trong [data]
  /// (kèm giá trị tham chiếu hiện tại).
  Map<String, dynamic> _collectOutside(DataSnapshot data) {
    List<int> idsOf(String table) => [
      for (final r in ((data[table] as List?) ?? const []))
        (r as Map<String, dynamic>)["id"] as int,
    ];
    final categories = idsOf("categories");
    final types = idsOf("types");
    final shops = idsOf("shops");
    final components = idsOf("components");
    final variants = idsOf("variants");
    final options = idsOf("options");
    final projects = idsOf("projects");
    final projectGroups = idsOf("projectGroups");
    final projectOptions = idsOf("projectOptions");
    final ownTypes = types.toSet();
    final ownComponents = components.toSet();
    final ownOptions = options.toSet();
    final ownProjectOptions = projectOptions.toSet();
    final ownProjectGroups = projectGroups.toSet();
    final ownItems = idsOf("projectItems").toSet();

    Iterable<T> query<T>(List<int> ids, QueryRelationToOne<T, dynamic> rel) =>
        ids.isEmpty
        ? const []
        : _db.get<T>().query(rel.anyOf(ids)).findAndClose();

    final componentRefs = {
      for (final c in [
        ...query(categories, Component_.category),
        ...query(types, Component_.type),
      ])
        if (!ownComponents.contains(c.id))
          c.id: {
            "id": c.id,
            "categoryId": c.category.targetId,
            "typeId": c.type.targetId,
          },
    };
    final typeRefs = {
      for (final t in query(categories, ComponentType_.category))
        if (!ownTypes.contains(t.id))
          t.id: {"id": t.id, "categoryId": t.category.targetId},
    };
    final projectOptionRefs = {
      for (final o in query(projects, ProjectOption_.project))
        if (!ownProjectOptions.contains(o.id))
          o.id: {
            "id": o.id,
            "projectId": o.project.targetId,
            "groupId": o.group.targetId,
          },
    };
    // Nhóm còn lại đang chọn phương án bị xoá => chọn lại khi hoàn tác
    final projectGroupRefs = {
      for (final g in query(projectOptions, ProjectGroup_.selected))
        if (!ownProjectGroups.contains(g.id))
          g.id: {"id": g.id, "selectedOptionId": g.selected.targetId},
    };

    // Tuỳ chọn bên ngoài trỏ tới shop / biến thể bị xoá
    final variantSet = variants.toSet();
    final optionRefs = <int, Map<String, dynamic>>{};
    for (final o in query(shops, ComponentOption_.shop)) {
      if (!ownOptions.contains(o.id)) {
        optionRefs[o.id] = {"id": o.id, "shopId": o.shop.targetId};
      }
    }
    if (variantSet.isNotEmpty) {
      for (final v
          in _db
              .get<ComponentVariant>()
              .getMany(variants)
              .whereType<ComponentVariant>()) {
        for (final o in v.options) {
          if (ownOptions.contains(o.id)) continue;
          optionRefs.putIfAbsent(
            o.id,
            () => {"id": o.id, "shopId": o.shop.targetId},
          );
          optionRefs[o.id]!["variantIds"] = o.variants
              .map((x) => x.id)
              .where(variantSet.contains)
              .toList();
        }
      }
    }

    final itemRefs = {
      for (final i in [
        ...query(components, ProjectItem_.component),
        ...query(variants, ProjectItem_.variant),
        ...query(options, ProjectItem_.componentOption),
        ...query(projects, ProjectItem_.project),
        ...query(projectOptions, ProjectItem_.projectOption),
      ])
        if (!ownItems.contains(i.id))
          i.id: {
            "id": i.id,
            "componentId": i.component.targetId,
            "variantId": i.variant.targetId,
            "componentOptionId": i.componentOption.targetId,
            "projectId": i.project.targetId,
            "projectOptionId": i.projectOption.targetId,
          },
    };

    // Nhật ký kho của biến thể / dự án bị xoá => nối lại khi hoàn tác
    final logRefs = {
      for (final l in [
        ...query(variants, StockLog_.variant),
        ...query(projects, StockLog_.project),
      ])
        l.id: {
          "id": l.id,
          "variantId": l.variant.targetId,
          "projectId": l.project.targetId,
        },
    };

    // Biến thể (không bị xoá) đang cất trong khay bị xoá
    final ownVariants = variants.toSet();
    final variantRefs = [
      for (final v in query(idsOf("storageTrays"), ComponentVariant_.tray))
        if (!ownVariants.contains(v.id))
          {
            "id": v.id,
            "trayId": v.tray.targetId,
            "compartmentIndex": v.compartmentIndex,
          },
    ];

    // Thành phần combo (của tuỳ chọn không bị xoá) trỏ tới biến thể bị xoá
    final partRefs = [
      for (final p in query(variants, ComboPart_.variant))
        if (!ownOptions.contains(p.option.targetId))
          {"id": p.id, "variantId": p.variant.targetId},
    ];

    return {
      "comboParts": partRefs,
      "variants": variantRefs,
      "stockLogs": logRefs.values.toList(),
      "components": componentRefs.values.toList(),
      "types": typeRefs.values.toList(),
      "options": optionRefs.values.toList(),
      "projectOptions": projectOptionRefs.values.toList(),
      "projectGroups": projectGroupRefs.values.toList(),
      "projectItems": itemRefs.values.toList(),
    };
  }

  /// Nối lại tham chiếu của bản ghi bên ngoài sang id mới.
  void _relinkOutside(
    Map<String, dynamic> outside,
    Map<String, Map<int, int>> ids,
  ) {
    List<Map<String, dynamic>> rows(String table) =>
        ((outside[table] as List?) ?? const []).cast<Map<String, dynamic>>();
    int remap(String table, Object? id) {
      final oldId = (id as int?) ?? 0;
      return ids[table]![oldId] ?? oldId;
    }

    final componentBox = _db.get<Component>();
    for (final r in rows("components")) {
      final c = componentBox.get(r["id"] as int);
      if (c == null) continue;
      c.category.targetId = remap("categories", r["categoryId"]);
      c.type.targetId = remap("types", r["typeId"]);
      componentBox.put(c);
    }

    final typeBox = _db.get<ComponentType>();
    for (final r in rows("types")) {
      final t = typeBox.get(r["id"] as int);
      if (t == null) continue;
      t.category.targetId = remap("categories", r["categoryId"]);
      typeBox.put(t);
    }

    final optionBox = _db.get<ComponentOption>();
    final variantBox = _db.get<ComponentVariant>();
    for (final r in rows("options")) {
      final o = optionBox.get(r["id"] as int);
      if (o == null) continue;
      o.shop.targetId = remap("shops", r["shopId"]);
      for (final oldVariantId in (r["variantIds"] as List? ?? const [])) {
        final variant = variantBox.get(remap("variants", oldVariantId));
        if (variant != null && !o.variants.any((v) => v.id == variant.id)) {
          o.variants.add(variant);
        }
      }
      optionBox.put(o);
    }

    final projectOptionBox = _db.get<ProjectOption>();
    for (final r in rows("projectOptions")) {
      final o = projectOptionBox.get(r["id"] as int);
      if (o == null) continue;
      o.project.targetId = remap("projects", r["projectId"]);
      if (r.containsKey("groupId")) {
        o.group.targetId = remap("projectGroups", r["groupId"]);
      }
      projectOptionBox.put(o);
    }

    final groupBox = _db.get<ProjectGroup>();
    for (final r in rows("projectGroups")) {
      final g = groupBox.get(r["id"] as int);
      if (g == null) continue;
      g.selected.targetId = remap("projectOptions", r["selectedOptionId"]);
      groupBox.put(g);
    }

    for (final r in rows("variants")) {
      final v = variantBox.get(r["id"] as int);
      if (v == null) continue;
      v.tray.targetId = remap("storageTrays", r["trayId"]);
      v.compartmentIndex = r["compartmentIndex"] as int? ?? 0;
      variantBox.put(v);
    }

    final partBox = _db.get<ComboPart>();
    for (final r in rows("comboParts")) {
      final p = partBox.get(r["id"] as int);
      if (p == null) continue;
      p.variant.targetId = remap("variants", r["variantId"]);
      partBox.put(p);
    }

    final logBox = _db.get<StockLog>();
    for (final r in rows("stockLogs")) {
      final l = logBox.get(r["id"] as int);
      if (l == null) continue;
      l.variant.targetId = remap("variants", r["variantId"]);
      l.project.targetId = remap("projects", r["projectId"]);
      logBox.put(l);
    }

    final itemBox = _db.get<ProjectItem>();
    for (final r in rows("projectItems")) {
      final i = itemBox.get(r["id"] as int);
      if (i == null) continue;
      i.component.targetId = remap("components", r["componentId"]);
      i.variant.targetId = remap("variants", r["variantId"]);
      i.componentOption.targetId = remap("options", r["componentOptionId"]);
      i.project.targetId = remap("projects", r["projectId"]);
      i.projectOption.targetId = remap("projectOptions", r["projectOptionId"]);
      itemBox.put(i);
    }
  }
}
