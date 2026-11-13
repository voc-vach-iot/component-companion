import 'package:component_companion/data/component_repository.dart';
import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/condition.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/combo_part.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/model/unit.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';

/// Hoàn tác 1 thao tác hàng loạt: ghi lại giá trị cũ của các bản ghi đã sửa.
class BulkUndo {
  final List<void Function()> _steps = [];

  void add(void Function() step) => _steps.add(step);

  /// Chạy ngược các bước theo thứ tự mới nhất trước.
  void run() {
    for (final step in _steps.reversed) {
      step();
    }
  }
}

/// Kết quả xem trước "đặt giá trị thuộc tính cho nhiều biến thể".
class AttributeAssignPlan {
  /// Biến thể sẽ đổi giá trị.
  final int changed;

  /// Biến thể đã có đúng giá trị đó.
  final int unchanged;

  /// Biến thể bỏ qua vì linh kiện của nó không có thuộc tính này.
  final int skipped;

  /// Số biến thể sẽ bị gộp vào biến thể khác (trùng tổ hợp sau khi đổi).
  /// > 0 thì không hoàn tác được.
  final int merged;

  const AttributeAssignPlan({
    this.changed = 0,
    this.unchanged = 0,
    this.skipped = 0,
    this.merged = 0,
  });
}

/// Thao tác hàng loạt trên linh kiện / biến thể / tuỳ chọn mua. Mỗi thao tác
/// chạy trong 1 transaction; những thao tác sửa tại chỗ trả về [BulkUndo].
class BulkEditService {
  final _db = ObjectboxService.instance;

  // --- Đổi tên linh kiện ---

  /// Đổi tên nhiều linh kiện: [names] = id -> tên mới. Ném
  /// [EntityAlreadyExistsException] nếu tên mới trùng nhau hoặc trùng linh
  /// kiện không nằm trong đợt đổi.
  BulkUndo renameComponents(Map<int, String> names) {
    final box = _db.get<Component>();
    final components = box.getMany(names.keys.toList()).whereType<Component>();
    final changing = {
      for (final c in components)
        if (names[c.id]!.trim().isNotEmpty && names[c.id]!.trim() != c.name)
          c.id: c,
    };
    final newNames = {
      for (final e in changing.entries) e.key: names[e.key]!.trim(),
    };

    final seen = <String>{};
    for (final name in newNames.values) {
      if (!seen.add(name)) {
        throw EntityAlreadyExistsException(
          "Có 2 linh kiện cùng tên mới '$name'.",
        );
      }
    }
    for (final e in newNames.entries) {
      final clash = box
          .query(
            Component_.name.equals(e.value) & Component_.id.notEquals(e.key),
          )
          .findFirstAndClose();
      if (clash != null && !changing.containsKey(clash.id)) {
        throw EntityAlreadyExistsException(
          "Linh kiện '${e.value}' đã tồn tại.",
        );
      }
    }

    final undo = BulkUndo();
    final olds = {for (final c in changing.values) c.id: c.name};
    _db.store.runInTransaction(TxMode.write, () {
      for (final c in changing.values) {
        c.name = newNames[c.id]!;
      }
      box.putMany(changing.values.toList());
    });
    undo.add(() {
      final current = box.getMany(olds.keys.toList()).whereType<Component>();
      for (final c in current) {
        c.name = olds[c.id]!;
      }
      box.putMany(current.toList());
    });
    return undo;
  }

  // --- Gán hàng loạt ---

  /// Gán danh mục / loại / ngưỡng cảnh báo cho nhiều linh kiện. Tham số null
  /// = giữ nguyên ([categoryId] / [typeId] = 0: bỏ phân loại).
  /// [threshold] là số lưu (theo đơn vị nhỏ nhất), áp cho mọi biến thể.
  BulkUndo assign(
    List<int> componentIds, {
    int? categoryId,
    int? typeId,
    int? threshold,
  }) {
    final box = _db.get<Component>();
    final variantBox = _db.get<ComponentVariant>();
    final components = box
        .getMany(componentIds)
        .whereType<Component>()
        .toList();
    final variants = variantBox
        .query(ComponentVariant_.component.anyOf(componentIds))
        .findAndClose();

    final oldCategory = {for (final c in components) c.id: c.category.targetId};
    final oldType = {for (final c in components) c.id: c.type.targetId};
    final oldThreshold = {for (final v in variants) v.id: v.lowStockThreshold};

    _db.store.runInTransaction(TxMode.write, () {
      if (categoryId != null || typeId != null) {
        for (final c in components) {
          if (categoryId != null) c.category.targetId = categoryId;
          if (typeId != null) c.type.targetId = typeId;
        }
        box.putMany(components);
      }
      if (threshold != null) {
        for (final v in variants) {
          v.lowStockThreshold = threshold;
        }
        variantBox.putMany(variants);
      }
    });

    return BulkUndo()..add(() {
      final cs = box.getMany(oldCategory.keys.toList()).whereType<Component>();
      for (final c in cs) {
        c.category.targetId = oldCategory[c.id]!;
        c.type.targetId = oldType[c.id]!;
      }
      box.putMany(cs.toList());
      final vs = variantBox
          .getMany(oldThreshold.keys.toList())
          .whereType<ComponentVariant>();
      for (final v in vs) {
        v.lowStockThreshold = oldThreshold[v.id]!;
      }
      variantBox.putMany(vs.toList());
    });
  }

  // --- Đổi đơn vị ---

  /// Đổi đơn vị của các linh kiện sang [to]. Số hiển thị giữ nguyên (12 cái
  /// → 12 m), số lưu nhân theo hệ số mới: tồn kho, đang về, ngưỡng, số mỗi
  /// gói (kèm lịch sử giá), số trong dự án, thành phần combo, nhật ký kho.
  /// Linh kiện đã đúng đơn vị thì bỏ qua.
  BulkUndo changeUnit(List<int> componentIds, QuantityUnit to) {
    final undo = BulkUndo();
    _db.store.runInTransaction(TxMode.write, () {
      for (final id in componentIds) {
        final c = _db.get<Component>().get(id);
        if (c == null || c.quantityUnit == to) continue;
        undo.add(_convert(c, c.quantityUnit, to));
      }
    });
    return undo;
  }

  /// Đổi số lưu theo hệ số, trả hàm hoàn tác (khôi phục giá trị cũ).
  void Function() _convert(Component c, QuantityUnit from, QuantityUnit to) {
    int conv(int v) => (v * to.scale / from.scale).round();
    int? convN(int? v) => v == null ? null : conv(v);

    final variantBox = _db.get<ComponentVariant>();
    final optionBox = _db.get<ComponentOption>();
    final recordBox = _db.get<PriceRecord>();
    final itemBox = _db.get<ProjectItem>();
    final partBox = _db.get<ComboPart>();
    final logBox = _db.get<StockLog>();
    final componentBox = _db.get<Component>();

    final variants = variantBox
        .query(ComponentVariant_.component.equals(c.id))
        .findAndClose();
    final variantIds = variants.map((v) => v.id).toList();
    // Chỉ tuỳ chọn thường: combo đếm theo "combo", không theo đơn vị
    final options = optionBox
        .query(ComponentOption_.component.equals(c.id))
        .findAndClose()
        .where((o) => !o.isCombo)
        .toList();
    final records = recordBox
        .query(PriceRecord_.option.anyOf(options.map((o) => o.id).toList()))
        .findAndClose();
    final items = itemBox
        .query(ProjectItem_.variant.anyOf(variantIds))
        .findAndClose();
    final parts = partBox
        .query(ComboPart_.variant.anyOf(variantIds))
        .findAndClose();
    final logs = logBox
        .query(StockLog_.variant.anyOf(variantIds))
        .findAndClose();

    final oldUnit = c.unit;
    final oldThreshold = c.lowStockThreshold;
    final oldVariants = <int, (int?, int, int)>{
      for (final v in variants)
        v.id: (v.stock, v.incoming, v.lowStockThreshold),
    };
    final oldOptions = {for (final o in options) o.id: o.unitsPerPack};
    final oldRecords = {for (final r in records) r.id: r.unitsPerPack};
    final oldItems = {for (final i in items) i.id: i.quantity};
    final oldParts = {for (final p in parts) p.id: p.quantity};
    final oldLogs = <int, (int?, int?, int)>{
      for (final l in logs) l.id: (l.before, l.after, l.marked),
    };

    c.unit = to.key;
    c.lowStockThreshold = conv(c.lowStockThreshold);
    componentBox.put(c);
    for (final v in variants) {
      v.stock = convN(v.stock);
      v.incoming = conv(v.incoming);
      v.lowStockThreshold = conv(v.lowStockThreshold);
    }
    variantBox.putMany(variants);
    for (final o in options) {
      o.unitsPerPack = conv(o.unitsPerPack).clamp(1, 1 << 40);
    }
    optionBox.putMany(options);
    for (final r in records) {
      r.unitsPerPack = conv(r.unitsPerPack).clamp(1, 1 << 40);
    }
    recordBox.putMany(records);
    for (final i in items) {
      i.quantity = conv(i.quantity);
    }
    itemBox.putMany(items);
    for (final p in parts) {
      p.quantity = conv(p.quantity);
    }
    partBox.putMany(parts);
    for (final l in logs) {
      l.before = convN(l.before);
      l.after = convN(l.after);
      l.marked = conv(l.marked);
    }
    logBox.putMany(logs);

    return () {
      _db.store.runInTransaction(TxMode.write, () {
        final cur = componentBox.get(c.id);
        if (cur != null) {
          cur.unit = oldUnit;
          cur.lowStockThreshold = oldThreshold;
          componentBox.put(cur);
        }
        _restore(variantBox, oldVariants, (v, o) {
          v.stock = o.$1;
          v.incoming = o.$2;
          v.lowStockThreshold = o.$3;
        }, (v) => v.id);
        _restore(
          optionBox,
          oldOptions,
          (o, n) => o.unitsPerPack = n,
          (o) => o.id,
        );
        _restore(
          recordBox,
          oldRecords,
          (r, n) => r.unitsPerPack = n,
          (r) => r.id,
        );
        _restore(itemBox, oldItems, (i, n) => i.quantity = n, (i) => i.id);
        _restore(partBox, oldParts, (p, n) => p.quantity = n, (p) => p.id);
        _restore(logBox, oldLogs, (l, o) {
          l.before = o.$1;
          l.after = o.$2;
          l.marked = o.$3;
        }, (l) => l.id);
      });
    };
  }

  void _restore<T, V>(
    Box<T> box,
    Map<int, V> olds,
    void Function(T entity, V old) apply,
    int Function(T entity) idOf,
  ) {
    final current = box.getMany(olds.keys.toList()).whereType<T>().toList();
    for (final e in current) {
      apply(e, olds[idOf(e)] as V);
    }
    box.putMany(current);
  }

  // --- Đổi tên tuỳ chọn mua ---

  /// Đổi tên tuỳ chọn mua: [names] = id tuỳ chọn -> tên mới.
  BulkUndo renameOptions(Map<int, String> names) {
    final box = _db.get<ComponentOption>();
    final options = box
        .getMany(names.keys.toList())
        .whereType<ComponentOption>()
        .where(
          (o) =>
              names[o.id]!.trim().isNotEmpty && names[o.id]!.trim() != o.name,
        )
        .toList();
    final olds = {for (final o in options) o.id: o.name};
    _db.store.runInTransaction(TxMode.write, () {
      for (final o in options) {
        o.name = names[o.id]!.trim();
      }
      box.putMany(options);
    });
    return BulkUndo()..add(() {
      final current = box
          .getMany(olds.keys.toList())
          .whereType<ComponentOption>();
      for (final o in current) {
        o.name = olds[o.id]!;
      }
      box.putMany(current.toList());
    });
  }

  // --- Giá trị thuộc tính của nhiều biến thể ---

  /// Xem trước việc đặt thuộc tính [attribute] = [value] cho [variantIds]
  /// (có thể thuộc nhiều linh kiện).
  AttributeAssignPlan previewAssign(
    List<int> variantIds,
    String attribute,
    String value,
  ) => _planAssign(variantIds, attribute, value).plan;

  /// Đặt thuộc tính [attribute] = [value] cho [variantIds]. Giá trị chưa có
  /// trong thuộc tính của linh kiện được thêm vào cuối. Biến thể bị trùng tổ
  /// hợp thì gộp (cộng tồn kho, trỏ lại dự án / tuỳ chọn mua); khi đó trả
  /// undo = null vì không hoàn tác được.
  ({BulkUndo? undo, AttributeAssignPlan plan}) assignAttribute(
    List<int> variantIds,
    String attribute,
    String value,
  ) {
    final planned = _planAssign(variantIds, attribute, value);
    if (planned.plan.changed == 0) {
      return (undo: BulkUndo(), plan: planned.plan);
    }

    final variantBox = _db.get<ComponentVariant>();
    final componentBox = _db.get<Component>();
    final repo = ComponentRepository();
    final oldSelections = {
      for (final v in planned.variants) v.id: v.selectionJson,
    };
    final oldAttributes = {
      for (final c in planned.components.values) c.id: c.attributesJson,
    };

    _db.store.runInTransaction(TxMode.write, () {
      for (final c in planned.components.values) {
        final attrs = c.attributes;
        final i = attrs.indexWhere((a) => a.name == attribute);
        if (i < 0 || attrs[i].values.contains(value)) continue;
        attrs[i] = VariantAttribute(attribute, [...attrs[i].values, value]);
        c.attributes = attrs;
        componentBox.put(c);
      }
      for (final v in planned.variants) {
        v.selection = {...v.selection, attribute: value};
      }
      variantBox.putMany(planned.variants);
      if (planned.plan.merged > 0) {
        for (final c in planned.components.values) {
          repo.resyncVariants(c);
        }
      }
    });

    if (planned.plan.merged > 0) return (undo: null, plan: planned.plan);
    final undo = BulkUndo()
      ..add(() {
        _db.store.runInTransaction(TxMode.write, () {
          _restore(
            variantBox,
            oldSelections,
            (v, s) => v.selectionJson = s,
            (v) => v.id,
          );
          _restore(
            componentBox,
            oldAttributes,
            (c, s) => c.attributesJson = s,
            (c) => c.id,
          );
        });
      });
    return (undo: undo, plan: planned.plan);
  }

  ({
    AttributeAssignPlan plan,
    List<ComponentVariant> variants,
    Map<int, Component> components,
  })
  _planAssign(List<int> variantIds, String attribute, String value) {
    final all = _db
        .get<ComponentVariant>()
        .getMany(variantIds)
        .whereType<ComponentVariant>();
    final components = <int, Component>{};
    final toChange = <ComponentVariant>[];
    var unchanged = 0, skipped = 0;
    for (final v in all) {
      final c = components[v.component.targetId] ??= v.component.target!;
      if (!c.attributes.any((a) => a.name == attribute)) {
        skipped++;
      } else if (v.selection[attribute] == value) {
        unchanged++;
      } else {
        toChange.add(v);
      }
    }

    // Trùng tổ hợp: tính trên toàn bộ biến thể của linh kiện sau khi đổi
    var merged = 0;
    final changing = {for (final v in toChange) v.id: v};
    for (final c in components.values) {
      final keys = <String>{};
      for (final v
          in _db
              .get<ComponentVariant>()
              .query(ComponentVariant_.component.equals(c.id))
              .findAndClose()) {
        final selection = changing.containsKey(v.id)
            ? {...v.selection, attribute: value}
            : v.selection;
        if (!keys.add(Variants.key(selection))) merged++;
      }
    }

    return (
      plan: AttributeAssignPlan(
        changed: toChange.length,
        unchanged: unchanged,
        skipped: skipped,
        merged: merged,
      ),
      variants: toChange,
      components: components,
    );
  }
}
