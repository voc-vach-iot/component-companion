import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/price_record.dart';
import 'package:component_companion/model/entities/project_item.dart';
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

  /// Tên shop bán (dùng để gom danh sách cần mua & so sánh giá).
  String shop;

  /// Phạm vi biến thể áp dụng dạng JSON (rỗng = mọi biến thể).
  String availabilityJson;

  /// Lần gần nhất giá được nhập / xác nhận.
  @Property(type: PropertyType.date)
  DateTime? priceCheckedAt;

  final component = ToOne<Component>();

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
    this.shop = "",
    this.availabilityJson = "",
    this.priceCheckedAt,
  });

  double get pricePerUnit =>
      unitsPerPack <= 0 ? pricePerPack.toDouble() : pricePerPack / unitsPerPack;

  VariantAvailability get availability =>
      Variants.decodeAvailability(availabilityJson);
  set availability(VariantAvailability value) =>
      availabilityJson = Variants.encodeAvailability(value);

  bool isAvailableFor(VariantSelection variant) =>
      Variants.isAvailable(availability, variant);

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
