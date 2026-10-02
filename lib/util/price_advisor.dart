import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/variant.dart';

/// Chọn tuỳ chọn mua hàng hợp lý theo biến thể và giá.
class PriceAdvisor {
  PriceAdvisor._();

  /// Chỉ gợi ý đổi khi rẻ hơn ít nhất tỉ lệ này.
  static const minSaving = 0.01;

  /// Tuỳ chọn áp dụng được cho biến thể, rẻ nhất (theo đơn giá) trước.
  static List<ComponentOption> availableOptions(
    Component component,
    VariantSelection variant,
  ) =>
      component.options.where((o) => o.isAvailableFor(variant)).toList()
        ..sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));

  static ComponentOption? cheapest(
    Component component,
    VariantSelection variant,
  ) => availableOptions(component, variant).firstOrNull;

  /// Tuỳ chọn rẻ hơn tuỳ chọn đang dùng của [item] (null nếu đang rẻ nhất).
  static ComponentOption? cheaperFor(ProjectItem item) {
    final component = item.component.target;
    if (component == null) return null;
    final best = cheapest(component, item.variant);
    final current = item.componentOption.target;
    if (best == null || best.id == current?.id) return null;
    if (current == null) return best;
    final saving = 1 - best.pricePerUnit / current.pricePerUnit;
    return saving >= minSaving ? best : null;
  }
}
