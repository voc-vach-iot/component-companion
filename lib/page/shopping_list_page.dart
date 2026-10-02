import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/stock_repository.dart';
import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/notifier/project_notifier.dart';
import 'package:component_companion/service/file_service.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/notification/snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Danh sách cần mua: gộp linh kiện của các dự án đã chọn, trừ tồn kho,
/// quy ra số gói và nhóm theo shop.
class ShoppingListPage extends HookConsumerWidget {
  /// Dự án được chọn sẵn (mở từ trang chi tiết dự án).
  final int? initialProjectId;

  const ShoppingListPage({super.key, this.initialProjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(watchAllProjectsWithItemsProvider);

    // null = chưa khởi tạo (chọn mặc định khi có dữ liệu)
    final selectedProjects = useState<Set<int>?>(null);
    final selectedVersions = useState<Set<int>>({});
    final subtractStock = useState(true);
    final useCheapest = useState(false);
    final checked = useState<Set<String>>({});

    useEffect(() {
      if (initialProjectId != null) {
        selectedProjects.value = {initialProjectId!};
      }
      return null;
    }, [initialProjectId]);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: projectsAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, s) => AppErrorView(message: "Lỗi tải dự án: $e"),
        data: (projects) {
          // Mặc định: dự án đang lập kế hoạch / đang thực hiện
          final selected =
              selectedProjects.value ??
              {
                for (final p in projects)
                  if (p.projectStatus == ProjectStatus.planning ||
                      p.projectStatus == ProjectStatus.inProgress)
                    p.id,
              };

          final entries = <({ProjectItem item, String usedIn})>[
            for (final p in projects.where((p) => selected.contains(p.id))) ...[
              for (final item in p.baseItems) (item: item, usedIn: p.name),
              for (final version in p.projectOptions)
                if (selectedVersions.value.contains(version.id))
                  for (final item in version.items)
                    (item: item, usedIn: "${p.name} · ${version.name}"),
            ],
          ];
          final lines = ShoppingList.build(
            entries,
            useCheapest: useCheapest.value,
            subtractStock: subtractStock.value,
          );
          final groups = ShoppingList.byShop(lines);
          final covered = lines.where((l) => l.isCovered).toList();
          final total = groups.fold(0, (sum, g) => sum + g.total);
          final missingOption = lines
              .where((l) => !l.isCovered && l.option == null)
              .length;

          Future<void> stockIn() async {
            final toStock = lines.where(
              (l) => checked.value.contains(l.key) && l.buyUnits > 0,
            );
            final repo = ref.read(stockRepositoryProvider);
            var count = 0;
            for (final l in toStock) {
              await repo.adjust(l.component.id, l.variant, l.buyUnits);
              count++;
            }
            checked.value = {};
            if (context.mounted) {
              AppSnackBar.show(
                context,
                message: "Đã nhập kho $count linh kiện",
                type: SnackBarType.success,
              );
            }
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CHỌN DỰ ÁN ---
              SizedBox(
                width: 300,
                child: _ProjectPicker(
                  projects: projects,
                  selected: selected,
                  selectedVersions: selectedVersions.value,
                  onToggleProject: (id) {
                    final next = {...selected};
                    next.contains(id) ? next.remove(id) : next.add(id);
                    selectedProjects.value = next;
                  },
                  onToggleVersion: (id) {
                    final next = {...selectedVersions.value};
                    next.contains(id) ? next.remove(id) : next.add(id);
                    selectedVersions.value = next;
                  },
                  subtractStock: subtractStock.value,
                  onSubtractStock: (v) => subtractStock.value = v,
                  useCheapest: useCheapest.value,
                  onUseCheapest: (v) => useCheapest.value = v,
                ),
              ),
              const SizedBox(width: 16),

              // --- DANH SÁCH ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Danh sách cần mua".toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Tổng: ${total.toVND()}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "${groups.length} shop · ${lines.length - covered.length} món cần mua"
                          "${covered.isEmpty ? "" : " · ${covered.length} món đủ trong kho"}",
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        AppButton(
                          label: "Sao chép",
                          icon: Icons.copy_rounded,
                          size: ButtonSize.small,
                          variant: ButtonVariant.secondary,
                          isDisabled: groups.isEmpty,
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: ShoppingList.toText(lines)),
                            );
                            if (context.mounted) {
                              AppSnackBar.show(
                                context,
                                message: "Đã sao chép danh sách (kèm link)",
                                type: SnackBarType.success,
                              );
                            }
                          },
                        ),
                        AppButton(
                          label: "Xuất CSV",
                          icon: Icons.table_view_outlined,
                          size: ButtonSize.small,
                          variant: ButtonVariant.secondary,
                          isDisabled: groups.isEmpty,
                          onPressed: () => FileService.saveText(
                            dialogTitle: "Lưu danh sách cần mua",
                            fileName:
                                "${FileService.timestamped("can-mua")}.csv",
                            content: ShoppingList.toCsv(lines),
                            extensions: const ["csv"],
                            withBom: true,
                          ),
                        ),
                        AppButton(
                          label: "Nhập kho đã chọn (${checked.value.length})",
                          icon: Icons.move_to_inbox_outlined,
                          size: ButtonSize.small,
                          isDisabled: checked.value.isEmpty,
                          onPressed: stockIn,
                        ),
                      ],
                    ),
                    if (missingOption > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          "$missingOption món chưa có tùy chọn mua hàng phù hợp biến thể nên chưa tính tiền.",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      "Tick các món đã mua rồi bấm \"Nhập kho\" để cộng vào tồn kho.",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: entries.isEmpty
                          ? const Center(
                              child: Text(
                                "Chọn dự án ở bên trái để lập danh sách",
                              ),
                            )
                          : ListView(
                              children: [
                                for (final group in groups)
                                  _ShopGroup(
                                    shop: group.shop,
                                    total: group.total,
                                    lines: group.lines,
                                    checked: checked.value,
                                    onToggle: (key) {
                                      final next = {...checked.value};
                                      next.contains(key)
                                          ? next.remove(key)
                                          : next.add(key);
                                      checked.value = next;
                                    },
                                    onToggleAll: (keys, value) {
                                      final next = {...checked.value};
                                      value
                                          ? next.addAll(keys)
                                          : next.removeAll(keys);
                                      checked.value = next;
                                    },
                                  ),
                                if (covered.isNotEmpty)
                                  _CoveredSection(lines: covered),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectPicker extends StatelessWidget {
  final List<Project> projects;
  final Set<int> selected;
  final Set<int> selectedVersions;
  final ValueChanged<int> onToggleProject;
  final ValueChanged<int> onToggleVersion;
  final bool subtractStock;
  final ValueChanged<bool> onSubtractStock;
  final bool useCheapest;
  final ValueChanged<bool> onUseCheapest;

  const _ProjectPicker({
    required this.projects,
    required this.selected,
    required this.selectedVersions,
    required this.onToggleProject,
    required this.onToggleVersion,
    required this.subtractStock,
    required this.onSubtractStock,
    required this.useCheapest,
    required this.onUseCheapest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            dense: true,
            title: const Text("Trừ số lượng đang có trong kho"),
            value: subtractStock,
            onChanged: onSubtractStock,
          ),
          SwitchListTile(
            dense: true,
            title: const Text("Mua ở tùy chọn rẻ nhất"),
            subtitle: const Text(
              "Tắt = theo tùy chọn đã chọn trong dự án",
              style: TextStyle(fontSize: 11),
            ),
            value: useCheapest,
            onChanged: onUseCheapest,
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              "DỰ ÁN",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: projects.isEmpty
                ? const Center(child: Text("Chưa có dự án"))
                : ListView(
                    children: [
                      for (final p in projects) ...[
                        CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selected.contains(p.id),
                          onChanged: (_) => onToggleProject(p.id),
                          title: Text(p.name),
                          subtitle: Text(
                            "${p.projectStatus.label} · ${p.baseItems.length} linh kiện",
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (selected.contains(p.id) &&
                            p.projectOptions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(56, 0, 12, 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final v in p.projectOptions)
                                  FilterChip(
                                    label: Text(
                                      "+ ${v.name}",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    selected: selectedVersions.contains(v.id),
                                    onSelected: (_) => onToggleVersion(v.id),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShopGroup extends StatelessWidget {
  final String shop;
  final int total;
  final List<ShoppingLine> lines;
  final Set<String> checked;
  final ValueChanged<String> onToggle;
  final void Function(List<String> keys, bool value) onToggleAll;

  const _ShopGroup({
    required this.shop,
    required this.total,
    required this.lines,
    required this.checked,
    required this.onToggle,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final keys = lines.map((l) => l.key).toList();
    final allChecked = keys.every(checked.contains);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: allChecked,
                  onChanged: (v) => onToggleAll(keys, v ?? false),
                ),
                const Icon(Icons.storefront_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shop,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  total.toVND(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          for (final line in lines)
            _LineTile(
              line: line,
              checked: checked.contains(line.key),
              onToggle: () => onToggle(line.key),
            ),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  final ShoppingLine line;
  final bool checked;
  final VoidCallback onToggle;

  const _LineTile({
    required this.line,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final option = line.option;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          children: [
            Checkbox(value: checked, onChanged: (_) => onToggle()),
            ComponentThumbnail.of(line.component, size: 40),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.component.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (line.variantLabel.isNotEmpty)
                    Text(
                      line.variantLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    "Dùng cho: ${line.usedIn.join(", ")}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                [
                  "Cần ${line.needed}",
                  if (line.stockTracked && line.subtractStock)
                    "có ${line.inStock}",
                  "thiếu ${line.shortage}",
                ].join(" · "),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              flex: 3,
              child: option == null
                  ? const Text(
                      "Chưa có tùy chọn mua",
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${line.packs} x ${option.name}",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "${option.pricePerPack.toVND()}/gói · ${option.pricePerUnit.toVND()}/cái"
                          "${line.buyUnits > line.shortage ? " · dư ${line.buyUnits - line.shortage}" : ""}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                line.cost.toVND(),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: option?.link.isNotEmpty == true
                  ? option!.link
                  : "Chưa có link",
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: option?.link.isNotEmpty == true
                  ? () => launchUrl(
                      Uri.parse(option!.link),
                      mode: LaunchMode.externalApplication,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoveredSection extends StatelessWidget {
  final List<ShoppingLine> lines;

  const _CoveredSection({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: const Icon(
          Icons.check_circle_outline,
          color: AppColors.success,
        ),
        title: Text("Đã đủ trong kho (${lines.length})"),
        children: [
          for (final l in lines)
            ListTile(
              dense: true,
              leading: ComponentThumbnail.of(l.component, size: 32),
              title: Text(
                l.variantLabel.isEmpty
                    ? l.component.name
                    : "${l.component.name} · ${l.variantLabel}",
              ),
              trailing: Text("Cần ${l.needed} · có ${l.inStock}"),
            ),
        ],
      ),
    );
  }
}
