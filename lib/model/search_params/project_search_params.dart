import 'package:component_companion/model/search_params/paging_search_params.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'project_search_params.mapper.dart';

@MappableClass()
class ProjectSearchParams extends PagingSearchParams
    with ProjectSearchParamsMappable {
  String name;

  /// Lọc theo trạng thái ([ProjectStatus.name]). Rỗng = mọi trạng thái.
  final List<String> statuses;

  ProjectSearchParams({
    this.name = "",
    this.statuses = const [],
    super.page = 0,
    super.size = 12,
    super.searchOptions,
    super.focusId,
  });
}
