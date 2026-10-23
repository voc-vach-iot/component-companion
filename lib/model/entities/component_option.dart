import 'package:component_companion/model/entities/combo_part.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/variant.dart';
import 'package:component_companion/util/combo_pricing.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:objectbox/objectbox.dart';

part 'component_option.mapper.dart';

@MappableClass(
  generateMethods: GenerateMethods.encode | GenerateMethods.decode,
  caseStyle: CaseStyle.camelCase,
)
@Entity()
class ComponentOption with ComponentOptionMappable {
  @Id()
  int id;
  String name;
  int unitsPerPack;
  int pricePerPack;
  String link;

  /// [CŨ] Tên shop dạng chuỗi trước khi có bảng Shop (chỉ dùng để chuyển dữ liệu).
  @Property(uid: 5021700049413886572)
  String legacyShopName;

  /// [CŨ] Phạm vi biến thể dạng JSON trước khi có bảng biến thể.
  @Property(uid: 2329143711318660867)
  String legacyAvailabilityJson;

  /// Lần gần nhất giá được nhập / xác nhận.
  @Property(type: PropertyType.date)
  DateTime? priceCheckedAt;

  final component = ToOne<Component>();

  final shop = ToOne<Shop>();

  /// Các biến thể áp dụng tuỳ chọn này (bắt buộc ít nhất 1).
  final variants = ToMany<ComponentVariant>();

  @Backlink("componentOption")
  final projectItem = ToMany<ProjectItem>();

  @Backlink("option")
  final priceHistory = ToMany<PriceRecord>();

  /// Thành phần của combo (rỗng = tuỳ chọn thường: [unitsPerPack] cái của 1
  /// trong các [variants]). Combo: [variants] = các biến thể trong combo,
  /// [unitsPerPack] = 1 (1 combo).
  @Backlink("option")
  final parts = ToMany<ComboPart>();

  /// Thành phần combo sẽ lưu (repository ghi lại khi add / update; null = giữ
  /// nguyên, rỗng = không phải combo).
  @Transient()
  List<ComboPart>? draftParts;

  ComponentOption({
    this.id = 0,
    required this.name,
    this.unitsPerPack = 1,
    required this.pricePerPack,
    this.link = "",
    this.legacyShopName = "",
    this.legacyAvailabilityJson = "",
    this.priceCheckedAt,
  });

  double get pricePerUnit =>
      unitsPerPack <= 0 ? pricePerPack.toDouble() : pricePerPack / unitsPerPack;

  bool get isCombo => parts.isNotEmpty;

  /// Đơn vị của [pricePerUnit] / lịch sử giá: combo tính theo "combo".
  String get unitLabel => isCombo ? "combo" : "cái";

  /// Số cái của biến thể [variantId] có trong 1 gói. Tuỳ chọn thường =>
  /// [unitsPerPack]; combo => số cái của biến thể đó trong combo (0 nếu không có).
  int unitsFor(int? variantId) {
    if (!isCombo || variantId == null || variantId == 0) return unitsPerPack;
    return parts
        .where((p) => p.variant.targetId == variantId)
        .fold(0, (sum, p) => sum + p.quantity);
  }

  /// Phần giá gói tính cho biến thể [variantId] (0..1). Combo chia theo đơn
  /// giá mua lẻ tham khảo của từng thành phần; thiếu giá lẻ thì chia theo số cái.
  double priceShare(int variantId) {
    if (!isCombo) return 1;
    final list = [
      for (final p in parts)
        if (p.variant.target case final v?) (variant: v, quantity: p.quantity),
    ];
    final shares = ComboPricing.shares(list);
    var mine = 0.0;
    for (var i = 0; i < list.length; i++) {
      if (list[i].variant.id == variantId) mine += shares[i];
    }
    return mine;
  }

  /// Đơn giá 1 cái của biến thể [variantId] khi mua theo tuỳ chọn này.
  double unitPriceFor(int? variantId) {
    if (!isCombo || variantId == null || variantId == 0) return pricePerUnit;
    final units = unitsFor(variantId);
    return units <= 0 ? 0 : pricePerPack * priceShare(variantId) / units;
  }

  /// "LCD1602 ×1 + PCF8574 ×1".
  String get contentsLabel => parts.map((p) => p.label).join(" + ");

  String get shopName => shop.target?.name ?? "";

  /// Nhãn "Shop · Quy cách".
  String get displayName => shopName.isEmpty ? name : "$shopName · $name";

  bool appliesTo(int variantId) => variants.any((v) => v.id == variantId);

  /// [CŨ] Phạm vi theo thuộc tính (chỉ dùng để chuyển dữ liệu).
  VariantAvailability get legacyAvailability =>
      Variants.decodeAvailability(legacyAvailabilityJson);

  /// Lịch sử giá theo thời gian tăng dần.
  List<PriceRecord> get sortedPriceHistory =>
      priceHistory.toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  // --- Helper methods ---
  static ComponentOption fromMap(Map<String, dynamic> map) =>
      ComponentOptionMapper.fromMap(map);

  static ComponentOption fromJson(String json) =>
      ComponentOptionMapper.fromJson(json);
}
