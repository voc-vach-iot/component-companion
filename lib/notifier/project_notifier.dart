import 'package:component_companion/service/stock_reservation.dart';
import 'package:component_companion/data/project_repository.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/search_params/project_search_params.dart';
import 'package:component_companion/service/stock_ledger.dart';
import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/project_stock.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/model/entities/project_group.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_notifier.g.dart';

@riverpod
class ProjectNotifier extends _$ProjectNotifier {
  @override
  void build() {}

  Future<int> addProject(Project project) async {
    final repository = ref.read(projectRepositoryProvider);
    return await repository.add(project);
  }

  Future<int> updateProject(Project project) async {
    final repository = ref.read(projectRepositoryProvider);
    return await repository.update(project);
  }

  Future<bool> deleteProject(int projectId) async {
    final repository = ref.read(projectRepositoryProvider);
    return await repository.delete(projectId);
  }
}

@riverpod
Stream<PageResult<Project>> watchProjects(
  Ref ref,
  ProjectSearchParams searchParams,
) {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.watchPaged(searchParams);
}

@riverpod
Stream<Project?> watchProjectById(Ref ref, int projectId) {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.watchById(projectId);
}

@riverpod
Stream<List<Project>> watchAllProjectsWithItems(Ref ref) {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.watchAllWithItems();
}

/// Tồn kho đang giữ cho các dự án "Đang thực hiện".
@riverpod
Stream<StockReservations> watchStockReservations(Ref ref) =>
    ref.watch(projectRepositoryProvider).watchAllWithItems().map((projects) {
      final ledger = StockLedger();
      return StockReservations.of(
        projects,
        consumed: {
          for (final p in projects)
            if (p.projectStatus == ProjectStatus.inProgress)
              p.id: ledger.consumedBy(p.id),
        },
      );
    });

/// Số dự án theo trạng thái.
@riverpod
Stream<Map<String, int>> watchProjectStatusCounts(Ref ref) =>
    ref.watch(projectRepositoryProvider).watchStatusCounts();

/// Tình trạng kho của dự án: đã lấy / cần theo cấu hình đang chọn.
@riverpod
Stream<({int consumed, int needed})> watchProjectStockStatus(
  Ref ref,
  int projectId,
) {
  final db = ObjectboxService.instance;
  return db
      .watchTables([
        db.store.watch<StockLog>(),
        db.store.watch<Project>(),
        db.store.watch<ProjectGroup>(),
        db.store.watch<ProjectOption>(),
        db.store.watch<ProjectItem>(),
      ])
      .map((_) {
        final project = db.get<Project>().get(projectId);
        return project == null
            ? (consumed: 0, needed: 0)
            : ProjectStockService().status(project);
      });
}
