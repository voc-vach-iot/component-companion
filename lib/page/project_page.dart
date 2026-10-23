import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/app_setting_repository.dart';
import 'package:component_companion/data/project_repository.dart';
import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/hook/use_page_effect.dart';
import 'package:component_companion/model/search_params/project_search_params.dart'; // Giả sử bạn có class này
import 'package:component_companion/notifier/project_notifier.dart';
import 'package:component_companion/notifier/search_options_notifier.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/view/grid_view.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/common/pagination.dart';
import 'package:component_companion/widget/project/project_action.dart';
import 'package:component_companion/widget/project/project_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProjectPage extends HookConsumerWidget {
  /// Lựa chọn lọc trạng thái được nhớ ở cài đặt (tên trạng thái, cách bằng ",").
  static const statusFilterKey = "projects.statusFilter";

  /// Mặc định chỉ hiện dự án đang thực hiện.
  static final defaultStatuses = [ProjectStatus.inProgress.name];

  const ProjectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingRepositoryProvider);
    final searchParamsNotifier = useState(
      ProjectSearchParams(
        statuses: switch (settings.get(statusFilterKey)) {
          null => defaultStatuses,
          final saved => [
            for (final s in saved.split(","))
              if (ProjectStatus.fromString(s) != null) s,
          ],
        },
      ),
    );
    final counts = ref.watch(watchProjectStatusCountsProvider).value ?? {};
    final statuses = searchParamsNotifier.value.statuses;

    void setStatuses(List<String> next) {
      settings.set(statusFilterKey, next.join(","));
      searchParamsNotifier.value = searchParamsNotifier.value.copyWith(
        statuses: next,
        page: 0,
      );
    }

    final searchOptions = ref.watch(searchOptionsProvider);
    final params = searchParamsNotifier.value.copyWith(
      searchOptions: searchOptions,
    );
    final search = useMemoized(() => TextSearch(params.name, searchOptions), [
      params.name,
      searchOptions,
    ]);

    final controller = useScrollController();

    // Watch danh sách dự án dựa trên searchParams
    final paged = usePagingEffect(
      pageResultAsync: ref.watch(watchProjectsProvider(params)),
      searchParamsNotifier: searchParamsNotifier,
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header: Tiêu đề + Tìm kiếm + Nút Thêm dự án
          AppHeader(
            title: "Quản lý dự án".toUpperCase(),
            onSearch: (value) {
              searchParamsNotifier.value = searchParamsNotifier.value.copyWith(
                name: value,
                page: 0,
              );
            },
            onAddPressed: () => ProjectAction.showAdd(
              context,
              ref,
              onSuccess: (id) {
                // Dự án mới ở trạng thái đang bị ẩn => hiện thêm trạng thái đó
                final status = ref
                    .read(projectRepositoryProvider)
                    .get(id)
                    ?.projectStatus
                    .name;
                if (status != null &&
                    statuses.isNotEmpty &&
                    !statuses.contains(status)) {
                  setStatuses([...statuses, status]);
                }
                paged.focusOn(id);
              },
            ),
          ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(
                    "Tất cả (${counts.values.fold(0, (a, b) => a + b)})",
                  ),
                  selected: statuses.isEmpty,
                  showCheckmark: false,
                  selectedColor: AppColors.primarySoft,
                  backgroundColor: AppColors.background,
                  onSelected: (_) => setStatuses(const []),
                ),
                for (final status in ProjectStatus.values)
                  FilterChip(
                    avatar: Icon(
                      status.icon,
                      size: 16,
                      color: status.foreground,
                    ),
                    label: Text(
                      "${status.label} (${counts[status.name] ?? 0})",
                    ),
                    selected: statuses.contains(status.name),
                    showCheckmark: false,
                    selectedColor: status.color,
                    backgroundColor: AppColors.background,
                    side: BorderSide(
                      color: statuses.contains(status.name)
                          ? status.foreground
                          : AppColors.border,
                    ),
                    onSelected: (v) => setStatuses([
                      for (final s in ProjectStatus.values)
                        if (s == status ? v : statuses.contains(s.name)) s.name,
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: paged.result.when(
              loading: () => const AppLoadingView(),
              error: (e, s) => AppErrorView(message: "Lỗi tải dự án: $e"),
              data: (pageResult) {
                if (pageResult.items.isEmpty && statuses.isNotEmpty) {
                  final hidden = counts.entries
                      .where((e) => !statuses.contains(e.key))
                      .fold(0, (sum, e) => sum + e.value);
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Không có dự án ở trạng thái đang chọn"
                          "${hidden > 0 ? " · $hidden dự án ở trạng thái khác" : ""}",
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        if (hidden > 0)
                          TextButton(
                            onPressed: () => setStatuses(const []),
                            child: const Text("Hiện tất cả"),
                          ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: GenericGrid(
                        maxWidth: 500,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        widthHeightRatio:
                            0.8, // Tùy chỉnh tỉ lệ khung hình cho Card dự án
                        scrollController: controller,
                        focus: paged.focus,
                        idOf: (project) => project.id,
                        items: pageResult.items,
                        itemBuilder: (context, project) {
                          return ProjectCard(
                            project: project,
                            search: search,
                            onTap: () =>
                                ProjectAction.showDetail(context, project),
                            onEdit: () =>
                                ProjectAction.showEdit(context, ref, project),
                            onDelete: () =>
                                ProjectAction.showDelete(context, ref, project),
                          );
                        },
                      ),
                    ),

                    // Pagination
                    const SizedBox(height: 16),
                    AppPagination(
                      currentPage: pageResult.currentPage,
                      totalPages: pageResult.totalPages,
                      onPageChange: (page) {
                        searchParamsNotifier.value = searchParamsNotifier.value
                            .copyWith(page: page);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
