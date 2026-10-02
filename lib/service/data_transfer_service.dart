import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/app_setting.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/entities/stock_item.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';

/// Ảnh chụp dữ liệu dạng JSON-friendly map: tên bảng -> danh sách bản ghi.
/// Mỗi bản ghi giữ id cũ và id quan hệ cũ; khi ghi lại sẽ được ánh xạ id mới.
typedef DataSnapshot = Map<String, dynamic>;

/// Xuất / nhập dữ liệu dùng cho: sao lưu - khôi phục và hoàn tác khi xoá.
class DataTransferService {
  static const format = "component-companion-backup";
  static const version = 1;

  static const _tables = [
    "categories",
    "types",
    "components",
    "options",
    "priceRecords",
    "stockItems",
    "projects",
    "projectOptions",
    "projectItems",
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
    components: _db.get<Component>().getAll(),
    options: _db.get<ComponentOption>().getAll(),
    priceRecords: _db.get<PriceRecord>().getAll(),
    stockItems: _db.get<StockItem>().getAll(),
    projects: _db.get<Project>().getAll(),
    projectOptions: _db.get<ProjectOption>().getAll(),
    projectItems: _db.get<ProjectItem>().getAll(),
    settings: _db.get<AppSetting>().getAll(),
  );

  /// Ảnh chụp các bản ghi sắp bị xoá (kèm dữ liệu phụ thuộc bị xoá theo) để hoàn tác.
  DataSnapshot snapshot({
    List<int> categoryIds = const [],
    List<int> typeIds = const [],
    List<int> componentIds = const [],
    List<int> optionIds = const [],
    List<int> projectIds = const [],
    List<int> projectOptionIds = const [],
    List<int> projectItemIds = const [],
  }) {
    final optionBox = _db.get<ComponentOption>();
    final itemBox = _db.get<ProjectItem>();
    final projectOptionBox = _db.get<ProjectOption>();

    // Linh kiện bị xoá kéo theo tuỳ chọn + tồn kho
    final allOptionIds = {
      ...optionIds,
      if (componentIds.isNotEmpty)
        ...optionBox
            .query(ComponentOption_.component.anyOf(componentIds))
            .getIdsAndClose(),
    }.toList();

    // Dự án bị xoá kéo theo phiên bản + linh kiện trong dự án
    final allProjectOptionIds = {
      ...projectOptionIds,
      if (projectIds.isNotEmpty)
        ...projectOptionBox
            .query(ProjectOption_.project.anyOf(projectIds))
            .getIdsAndClose(),
    }.toList();
    final allItemIds = {
      ...projectItemIds,
      if (projectIds.isNotEmpty)
        ...itemBox
            .query(ProjectItem_.project.anyOf(projectIds))
            .getIdsAndClose(),
      if (allProjectOptionIds.isNotEmpty)
        ...itemBox
            .query(ProjectItem_.projectOption.anyOf(allProjectOptionIds))
            .getIdsAndClose(),
    }.toList();

    List<T> many<T>(List<int> ids) =>
        _db.get<T>().getMany(ids).whereType<T>().toList();

    final data = _build(
      categories: many<Category>(categoryIds),
      types: many<ComponentType>(typeIds),
      components: many<Component>(componentIds),
      options: many<ComponentOption>(allOptionIds),
      priceRecords: allOptionIds.isEmpty
          ? const []
          : _db
                .get<PriceRecord>()
                .query(PriceRecord_.option.anyOf(allOptionIds))
                .findAndClose(),
      stockItems: componentIds.isEmpty
          ? const []
          : _db
                .get<StockItem>()
                .query(StockItem_.component.anyOf(componentIds))
                .findAndClose(),
      projects: many<Project>(projectIds),
      projectOptions: many<ProjectOption>(allProjectOptionIds),
      projectItems: many<ProjectItem>(allItemIds),
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
    required List<Component> components,
    required List<ComponentOption> options,
    required List<PriceRecord> priceRecords,
    required List<StockItem> stockItems,
    required List<Project> projects,
    required List<ProjectOption> projectOptions,
    required List<ProjectItem> projectItems,
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
    "options": [
      for (final o in options)
        {
          "id": o.id,
          "componentId": o.component.targetId,
          "name": o.name,
          "unitsPerPack": o.unitsPerPack,
          "pricePerPack": o.pricePerPack,
          "link": o.link,
          "shop": o.shop,
          "availabilityJson": o.availabilityJson,
          "priceCheckedAt": o.priceCheckedAt?.millisecondsSinceEpoch,
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
    "stockItems": [
      for (final s in stockItems)
        {
          "id": s.id,
          "componentId": s.component.targetId,
          "quantity": s.quantity,
          "location": s.location,
          "variantJson": s.variantJson,
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
    "projectOptions": [
      for (final o in projectOptions)
        {
          "id": o.id,
          "projectId": o.project.targetId,
          "name": o.name,
          "description": o.description,
        },
    ],
    "projectItems": [
      for (final i in projectItems)
        {
          "id": i.id,
          "quantity": i.quantity,
          "variantJson": i.variantJson,
          "componentId": i.component.targetId,
          "componentOptionId": i.componentOption.targetId,
          "projectOptionId": i.projectOption.targetId,
          "projectId": i.project.targetId,
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
      _db.get<ProjectItem>().removeAll();
      _db.get<ProjectOption>().removeAll();
      _db.get<Project>().removeAll();
      _db.get<StockItem>().removeAll();
      _db.get<PriceRecord>().removeAll();
      _db.get<ComponentOption>().removeAll();
      _db.get<Component>().removeAll();
      _db.get<ComponentType>().removeAll();
      _db.get<Category>().removeAll();
      _db.get<AppSetting>().removeAll();
      _insert(data, relinkOutside: false);
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

    final optionBox = _db.get<ComponentOption>();
    for (final r in rows("options")) {
      final checkedAt = r["priceCheckedAt"] as int?;
      ids["options"]![r["id"] as int] = optionBox.put(
        ComponentOption(
          name: r["name"] as String,
          unitsPerPack: r["unitsPerPack"] as int? ?? 1,
          pricePerPack: r["pricePerPack"] as int? ?? 0,
          link: r["link"] as String? ?? "",
          shop: r["shop"] as String? ?? "",
          availabilityJson: r["availabilityJson"] as String? ?? "",
          priceCheckedAt: checkedAt == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(checkedAt),
        )..component.targetId = map("components", r["componentId"]),
      );
    }

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

    final projectOptionBox = _db.get<ProjectOption>();
    for (final r in rows("projectOptions")) {
      ids["projectOptions"]![r["id"] as int] = projectOptionBox.put(
        ProjectOption(
          name: r["name"] as String,
          description: r["description"] as String? ?? "",
        )..project.targetId = map("projects", r["projectId"]),
      );
    }

    _db.get<ProjectItem>().putMany([
      for (final r in rows("projectItems"))
        ProjectItem(
            quantity: r["quantity"] as int? ?? 1,
            variantJson: r["variantJson"] as String? ?? "",
          )
          ..component.targetId = map("components", r["componentId"])
          ..componentOption.targetId = map("options", r["componentOptionId"])
          ..projectOption.targetId = map("projectOptions", r["projectOptionId"])
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
    final components = idsOf("components");
    final options = idsOf("options");
    final projects = idsOf("projects");
    final projectOptions = idsOf("projectOptions");
    final ownTypes = types.toSet();
    final ownComponents = components.toSet();
    final ownProjectOptions = projectOptions.toSet();
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
          o.id: {"id": o.id, "projectId": o.project.targetId},
    };
    final itemRefs = {
      for (final i in [
        ...query(components, ProjectItem_.component),
        ...query(options, ProjectItem_.componentOption),
        ...query(projects, ProjectItem_.project),
        ...query(projectOptions, ProjectItem_.projectOption),
      ])
        if (!ownItems.contains(i.id))
          i.id: {
            "id": i.id,
            "componentId": i.component.targetId,
            "componentOptionId": i.componentOption.targetId,
            "projectId": i.project.targetId,
            "projectOptionId": i.projectOption.targetId,
          },
    };

    return {
      "components": componentRefs.values.toList(),
      "types": typeRefs.values.toList(),
      "projectOptions": projectOptionRefs.values.toList(),
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

    final projectOptionBox = _db.get<ProjectOption>();
    for (final r in rows("projectOptions")) {
      final o = projectOptionBox.get(r["id"] as int);
      if (o == null) continue;
      o.project.targetId = remap("projects", r["projectId"]);
      projectOptionBox.put(o);
    }

    final itemBox = _db.get<ProjectItem>();
    for (final r in rows("projectItems")) {
      final i = itemBox.get(r["id"] as int);
      if (i == null) continue;
      i.component.targetId = remap("components", r["componentId"]);
      i.componentOption.targetId = remap("options", r["componentOptionId"]);
      i.project.targetId = remap("projects", r["projectId"]);
      i.projectOption.targetId = remap("projectOptions", r["projectOptionId"]);
      itemBox.put(i);
    }
  }
}
