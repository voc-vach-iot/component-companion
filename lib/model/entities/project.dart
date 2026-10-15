import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:objectbox/objectbox.dart';

part 'project.mapper.dart';

@MappableClass(
  generateMethods: GenerateMethods.encode | GenerateMethods.decode,
  caseStyle: CaseStyle.camelCase,
)
@Entity()
class Project with ProjectMappable {
  @Id()
  int id;
  String name;
  String description;
  String base64Image;
  int updatedAt;
  String status;

  @Backlink("project")
  final baseItems = ToMany<ProjectItem>();

  @Backlink("project")
  final projectOptions = ToMany<ProjectOption>();

  @Backlink("project")
  final groups = ToMany<ProjectGroup>();

  Project({
    this.id = 0,
    required this.name,
    this.description = "",
    this.base64Image = "",
    this.updatedAt = 0,
    this.status = "",
  }) {
    if (status.isEmpty) {
      status = ProjectStatus.planning.name;
    }
    if (updatedAt == 0) {
      updatedAt = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Nhóm lựa chọn theo thứ tự hiển thị.
  List<ProjectGroup> get sortedGroups => groups.toList()
    ..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });

  /// Linh kiện của cấu hình đang chọn: phần chung + phương án đang chọn ở mỗi
  /// nhóm. [usedIn] là nhãn nguồn, VD "Robot" hoặc "Robot · Pin: 2000mAh".
  List<({ProjectItem item, String usedIn})> get configurationEntries => [
    for (final item in baseItems) (item: item, usedIn: name),
    for (final g in sortedGroups)
      if (g.selectedOption case final o?)
        for (final item in o.items)
          (item: item, usedIn: "$name · ${g.name}: ${o.name}"),
  ];

  List<ProjectItem> get configurationItems => [
    for (final e in configurationEntries) e.item,
  ];

  /// Tổng tiền cấu hình đang chọn (theo đơn giá).
  double get configurationPrice =>
      configurationItems.fold(0.0, (sum, i) => sum + i.totalPrice);

  // Lưu ý: là method chứ không phải getter — getter trả về record làm
  // objectbox_generator lỗi và từng làm entity Project bị tạo lại (mất id cũ).
  /// Giá cấu hình rẻ nhất / đắt nhất có thể (mỗi nhóm chọn phương án rẻ /
  /// đắt nhất). Bằng nhau => dự án chỉ có 1 cấu hình.
  ({double min, double max}) configurationPriceRange() {
    final base = baseItems.fold(0.0, (sum, i) => sum + i.totalPrice);
    var min = base, max = base;
    for (final g in groups) {
      final prices = [for (final o in g.options) o.totalPrice];
      if (prices.isEmpty) continue;
      min += prices.reduce((a, b) => a < b ? a : b);
      max += prices.reduce((a, b) => a > b ? a : b);
    }
    return (min: min, max: max);
  }

  ProjectStatus get projectStatus =>
      ProjectStatus.fromString(status) ?? ProjectStatus.planning;

  // Helper methods
  static Project fromMap(Map<String, dynamic> map) =>
      ProjectMapper.fromMap(map);

  static Project fromJson(String json) => ProjectMapper.fromJson(json);
}
