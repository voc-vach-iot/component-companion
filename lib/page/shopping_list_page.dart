import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/data/variant_repository.dart';
import 'package:component_companion/util/price_insight.dart';
import 'package:component_companion/util/purchase_planner.dart';
import 'package:component_companion/enum/project_status.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/extension/toast/future_toast.dart';
import 'package:component_companion/notifier/project_group_notifier.dart';
import 'package:component_companion/notifier/project_notifier.dart';
import 'package:component_companion/service/file_service.dart';
import 'package:component_companion/service/project_stock.dart';
import 'package:component_companion/service/shopping_list.dart';
import 'package:component_companion/service/stock_reservation.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/component/price_history_dialog.dart';
import 'package:component_companion/notifier/variant_notifier.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/stock_log.dart';
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
    final subtractStock = useState(true);
    final keepReserved = useState(true);
    final reservations =
        ref.watch(watchStockReservationsProvider).value ??
        StockReservations.empty;
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

          // Mỗi dự án lấy cấu hình đang chọn: phần chung + phương án đang
          // chọn của từng nhóm lựa chọn
          final entries = <({ProjectItem item, String usedIn})>[
            for (final p in projects.where((p) => selected.contains(p.id)))
              ...p.configurationEntries,
          ];
          final lines = ShoppingList.build(
            entries,
            useCheapest: useCheapest.value,
            subtractStock: subtractStock.value,
            // Hàng đang giữ cho dự án "Đang thực hiện" chưa được chọn ở đây
            reserved: keepReserved.value
                ? reservations.totals(except: selected)
                : const {},
            // Phần các dự án đã lấy khỏi kho (đã trừ kho) thì không cần nữa
            allocated: ProjectStockService().allocated(selected),
          );
          final groups = ShoppingList.byShop(lines);
          final covered = lines.where((l) => l.isCovered).toList();
          final total = groups.fold(0, (sum, g) => sum + g.total);
          final missingOption = lines
              .where((l) => !l.isCovered && l.plan.isEmpty)
              .length;

          Future<void> stockIn() async {
            final toStock = lines
                .where((l) => checked.value.contains(l.key) && l.buyUnits > 0)
                .toList();
            final repo = ref.read(variantRepositoryProvider);
            final messenger = ScaffoldMessenger.of(context);
            // Ghi lại tồn kho cũ để hoàn tác
            final previous = <int, int?>{};
            final previousChecked = checked.value;
            // Combo => cộng cả linh kiện đi kèm, combo chung chỉ tính 1 lần
            final received = ShoppingList.receivedUnits(toStock);
            for (final e in received.entries) {
              previous.putIfAbsent(e.key, () => repo.get(e.key)?.stock);
              await repo.adjustStock(
                e.key,
                e.value,
                reason: StockReason.stockIn,
              );
            }
            checked.value = {};
            AppSnackBar.showWith(
              messenger,
              message: "Đã nhập kho ${toStock.length} linh kiện",
              type: SnackBarType.success,
              duration: const Duration(seconds: 10),
              actionLabel: "Hoàn tác",
              onAction: () async {
                await repo.restoreStocks(previous);
                if (context.mounted) checked.value = previousChecked;
                AppSnackBar.showWith(
                  messenger,
                  message: "Đã trả lại tồn kho cũ",
                  type: SnackBarType.info,
                );
              },
            );
          }

          // Đã đặt mua => cộng vào "đang về" (trang tự trừ khỏi số cần mua)
          Future<void> markOrdered() async {
            final ordered = ShoppingList.receivedUnits(
              lines.where(
                (l) => checked.value.contains(l.key) && l.buyUnits > 0,
              ),
            );
            if (ordered.isEmpty) return;
            final repo = ref.read(variantRepositoryProvider);
            final messenger = ScaffoldMessenger.of(context);
            final previousChecked = checked.value;
            final previous = await repo.addIncoming(ordered).withToast(context);
            if (previous == null) return;
            checked.value = {};
            AppSnackBar.showWith(
              messenger,
              message:
                  "Đã đánh dấu đặt mua ${ordered.length} linh kiện (đang về)",
              type: SnackBarType.success,
              duration: const Duration(seconds: 10),
              actionLabel: "Hoàn tác",
              onAction: () async {
                await repo.restoreIncoming(previous);
                if (context.mounted) checked.value = previousChecked;
              },
            );
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
                  onToggleProject: (id) {
                    final next = {...selected};
                    next.contains(id) ? next.remove(id) : next.add(id);
                    selectedProjects.value = next;
                  },
                  onSelectOption: (option) => ref
                      .read(projectGroupProvider.notifier)
                      .select(option.id)
                      .withToast(context),
                  subtractStock: subtractStock.value,
                  onSubtractStock: (v) => subtractStock.value = v,
                  keepReserved: keepReserved.value,
                  onKeepReserved: (v) => keepReserved.value = v,
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
                          label: "Đã đặt (${checked.value.length})",
                          icon: Icons.local_shipping_outlined,
                          size: ButtonSize.small,
                          variant: ButtonVariant.secondary,
                          isDisabled: checked.value.isEmpty,
                          onPressed: markOrdered,
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
                      "Tick các món rồi bấm \"Đã đặt\" khi vừa đặt hàng (chuyển vào \"Đang về\", "
                      "không cần mua thêm) hoặc \"Nhập kho\" khi đã có hàng.",
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
                                const _IncomingSection(),
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
  final ValueChanged<int> onToggleProject;

  /// Đổi phương án đang dùng của 1 nhóm (lưu vào dự án).
  final ValueChanged<ProjectOption> onSelectOption;
  final bool subtractStock;
  final bool keepReserved;
  final ValueChanged<bool> onKeepReserved;
  final ValueChanged<bool> onSubtractStock;
  final bool useCheapest;
  final ValueChanged<bool> onUseCheapest;

  const _ProjectPicker({
    required this.projects,
    required this.selected,
    required this.onToggleProject,
    required this.onSelectOption,
    required this.subtractStock,
    required this.keepReserved,
    required this.onKeepReserved,
    required this.onSubtractStock,
    required this.useCheapest,
    required this.onUseCheapest,
  });

  @override
  Widget build(BuildContext context) {
    // Material riêng để ListTile vẽ được nền / hiệu ứng bấm trên nền Container
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            dense: true,
            title: const Text("Trừ số lượng đang có trong kho"),
            value: subtractStock,
            onChanged: onSubtractStock,
          ),
          if (subtractStock)
            SwitchListTile(
              dense: true,
              title: const Text("Chừa hàng cho dự án đang thực hiện"),
              subtitle: const Text(
                "Không tính phần kho đã dành cho dự án \"Đang thực hiện\" khác",
                style: TextStyle(fontSize: 11),
              ),
              value: keepReserved,
              onChanged: onKeepReserved,
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
                            "${p.projectStatus.label} · ${p.configurationItems.length} linh kiện",
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (selected.contains(p.id))
                          for (final g in p.sortedGroups)
                            if (g.options.length > 1)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  56,
                                  0,
                                  12,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final o in g.sortedOptions)
                                          ChoiceChip(
                                            label: Text(
                                              o.name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            selected:
                                                g.selectedOption?.id == o.id,
                                            onSelected: (_) =>
                                                onSelectOption(o),
                                          ),
                                      ],
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
    final plan = line.plan;
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
                  if (line.allocated > 0) "đã lấy ${line.allocated}",
                  if (line.stockTracked && line.subtractStock)
                    line.reserved > 0
                        ? "có ${line.inStock} (giữ ${line.reserved} cho dự án khác)"
                        : "có ${line.inStock}",
                  if (line.incoming > 0 && line.subtractStock)
                    "đang về ${line.incoming}",
                  "thiếu ${line.shortage}",
                ].join(" · "),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              flex: 3,
              child: plan.isEmpty
                  ? const Text(
                      "Chưa có tùy chọn mua",
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        for (final p in plan.parts)
                          if (PriceInsight.increase(
                                p.option,
                                line.variant.options,
                              )
                              case final up?)
                            _PriceIncreaseChip(up),
                        if (plan.hasCombo)
                          Text(
                            [
                              for (final p in plan.parts)
                                if (p.option.isCombo)
                                  "Combo: ${p.option.contentsLabel}",
                              if (plan.sharedWith.isNotEmpty)
                                "mua chung với ${plan.sharedWith.join(", ")}",
                            ].join(" · "),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                            ),
                          ),
                        Text(
                          [
                                for (final p in plan.parts)
                                  p.option.isCombo
                                      ? "${p.option.pricePerPack.toVND()}/combo"
                                      : "${p.option.pricePerPack.toVND()}/${p.option.unitsPerPack} cái",
                              ].join(" · ") +
                              (line.buyUnits > line.shortage
                                  ? " · dư ${line.buyUnits - line.shortage}"
                                  : ""),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
            _LinkButton(plan: plan),
          ],
        ),
      ),
    );
  }
}

/// Mở link mua. Phương án nhiều gói khác link => menu chọn link.
class _LinkButton extends StatelessWidget {
  final PurchasePlan plan;

  const _LinkButton({required this.plan});

  void _open(String link) =>
      launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final links = <String, String>{
      for (final p in plan.parts)
        if (p.option.link.isNotEmpty) p.option.link: p.option.name,
    };
    if (links.length <= 1) {
      final link = links.keys.firstOrNull;
      return IconButton(
        tooltip: link ?? "Chưa có link",
        icon: const Icon(Icons.open_in_new, size: 18),
        onPressed: link == null ? null : () => _open(link),
      );
    }
    return PopupMenuButton<String>(
      tooltip: "Mở link",
      icon: const Icon(Icons.open_in_new, size: 18),
      color: AppColors.background,
      onSelected: _open,
      itemBuilder: (context) => [
        for (final e in links.entries)
          PopupMenuItem(value: e.key, child: Text(e.value)),
      ],
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
              trailing: Text(
                l.needed == 0 && l.allocated > 0
                    ? "Đã lấy đủ ${l.allocated} khỏi kho"
                    : "Cần ${l.needed} · có ${l.inStock}",
              ),
            ),
        ],
      ),
    );
  }
}

/// Nhãn "giá tăng" của 1 tùy chọn trong phương án mua. Bấm => lịch sử giá.
class _PriceIncreaseChip extends StatelessWidget {
  final PriceIncrease increase;

  const _PriceIncreaseChip(this.increase);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: increase.tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => showDialog(
          context: context,
          builder: (_) => PriceHistoryDialog(option: increase.option),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.trending_up_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  increase.fromOtherOption
                      ? "${increase.label} (tùy chọn khác)"
                      : increase.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hàng đã đặt, chưa nhận (mọi dự án). "Đã nhận" => chuyển vào tồn kho.
class _IncomingSection extends ConsumerWidget {
  const _IncomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants = ref.watch(watchIncomingVariantsProvider).value ?? const [];
    if (variants.isEmpty) return const SizedBox.shrink();
    final sorted = [...variants]
      ..sort(
        (a, b) => _label(a).toLowerCase().compareTo(_label(b).toLowerCase()),
      );

    Future<void> receive(List<ComponentVariant> list) async {
      final repo = ref.read(variantRepositoryProvider);
      final messenger = ScaffoldMessenger.of(context);
      final previous = await repo
          .receive(list.map((v) => v.id).toList())
          .withToast(context);
      if (previous == null) return;
      AppSnackBar.showWith(
        messenger,
        message: "Đã nhận ${previous.incoming.length} linh kiện vào kho",
        type: SnackBarType.success,
        duration: const Duration(seconds: 10),
        actionLabel: "Hoàn tác",
        onAction: () async {
          await repo.restoreStocks(previous.stocks);
          await repo.restoreIncoming(previous.incoming);
        },
      );
    }

    // Material riêng để ListTile vẽ được nền / hiệu ứng bấm
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.info.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: const Icon(
              Icons.local_shipping_outlined,
              color: AppColors.info,
            ),
            title: Text(
              "Đang về (${variants.length})",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              "Đã đặt, chưa nhận — đã trừ khỏi số cần mua",
              style: TextStyle(fontSize: 11),
            ),
            trailing: AppButton(
              label: "Nhận tất cả",
              icon: Icons.move_to_inbox_outlined,
              size: ButtonSize.small,
              variant: ButtonVariant.secondary,
              onPressed: () => receive(sorted),
            ),
            children: [
              for (final v in sorted)
                ListTile(
                  dense: true,
                  leading: v.component.target == null
                      ? null
                      : ComponentThumbnail.of(v.component.target!, size: 32),
                  title: Text(_label(v)),
                  subtitle: Text(
                    "Đang về ${v.incoming}"
                    "${v.stock == null ? "" : " · trong kho ${v.stock}"}",
                  ),
                  trailing: TextButton.icon(
                    onPressed: () => receive([v]),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text("Đã nhận"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _label(ComponentVariant v) {
    final c = v.component.target;
    if (c == null) return v.label;
    return v.isDefault ? c.name : "${c.name} · ${v.labelFor(c.attributes)}";
  }
}
