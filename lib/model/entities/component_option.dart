import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/shop.dart';
import 'package:component_companion/model/variant.dart';
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

  String get shopName => shop.target?.name ?? "";

  /// Nhãn "Shop · Quy cách".
  String get displayName =>
      shopName.isEmpty ? name : "$shopName · $name";

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
