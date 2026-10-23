import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:objectbox/objectbox.dart';

/// 1 thành phần của tuỳ chọn mua dạng combo: 1 gói combo có [quantity] cái
/// của [variant]. VD combo "LCD1602 + PCF8574" = LCD1602 ×1 + PCF8574 ×1;
/// "XT60 1 cặp" = đực ×1 + cái ×1; "Vít kèm ốc" = vít ×100 + ốc ×100.
@Entity()
class ComboPart {
  @Id()
  int id;

  int quantity;

  final option = ToOne<ComponentOption>();
  final variant = ToOne<ComponentVariant>();

  ComboPart({this.id = 0, this.quantity = 1});

  /// "LCD1602 · 5V ×1".
  String get label {
    final v = variant.target;
    final c = v?.component.target;
    if (v == null || c == null) return "(đã xoá) ×$quantity";
    final name = v.isDefault
        ? c.name
        : "${c.name} · ${v.labelFor(c.attributes)}";
    return "$name ×$quantity";
  }
}
