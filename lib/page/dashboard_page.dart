import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/notifier/dashboard_notifier.dart';
import 'package:component_companion/service/dashboard_service.dart';
import 'package:component_companion/util/price_insight.dart';
import 'package:component_companion/widget/common/error_view.dart';
import 'package:component_companion/widget/common/loading_view.dart';
import 'package:component_companion/widget/component/component_option_action.dart';
import 'package:component_companion/widget/component/component_thumbnail.dart';
import 'package:component_companion/widget/component/variant_action.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(watchDashboardProvider);

    return dataAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, s) => AppErrorView(message: "Lỗi tải tổng quan: $e"),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "Tổng quan".toUpperCase(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatTile(
                  icon: Icons.extension_outlined,
                  label: "Linh kiện",
                  value: "${data.componentCount}",
                  sub: "${data.trackedCount} đang theo dõi tồn kho",
                ),
                _StatTile(
                  icon: Icons.inventory_2_outlined,
                  label: "Giá trị kho",
                  value: data.stockValue.toVND(),
                  sub: "Theo đơn giá rẻ nhất",
                ),
                _StatTile(
                  icon: Icons.warning_amber_rounded,
                  label: "Sắp hết / hết hàng",
                  value: "${data.lowStock.length}",
                  color: data.lowStock.isEmpty ? null : AppColors.warning,
                ),
                _StatTile(
                  icon: Icons.schedule,
                  label: "Giá cần kiểm tra lại",
                  value: "${data.stalePrices.length}",
                  sub:
                      "Quá ${PriceInsight.staleAfter.inDays} ngày chưa kiểm tra",
                  color: data.stalePrices.isEmpty ? null : AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth > 1000;
                final left = [
                  _ProjectsCard(data: data),
                  _LowStockCard(data: data),
                ];
                final right = [
                  _PriceIncreaseCard(data: data),
                  _StalePriceCard(data: data),
                  _CategoryValueCard(data: data),
                ];
                if (!twoColumns) {
                  return Column(children: [...left, ...right]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: left)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(children: right)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color? color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color ?? AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30, color: color ?? AppColors.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textMuted)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color ?? AppColors.textMain,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

const _empty = Padding(
  padding: EdgeInsets.symmetric(vertical: 8),
  child: Text("Không có mục nào", style: TextStyle(color: AppColors.textMuted)),
);

class _ProjectsCard extends StatelessWidget {
  final DashboardData data;

  const _ProjectsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: "Chi phí dự án (phần cơ bản)",
      icon: Icons.folder_outlined,
      trailing: TextButton(
        onPressed: () => context.go("/shopping"),
        child: const Text("Danh sách cần mua"),
      ),
      child: data.projects.isEmpty
          ? _empty
          : Column(
              children: [
                for (final p in data.projects)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () => context.go("/project/${p.project.id}"),
                    title: Text(p.project.name),
                    subtitle: Text(p.project.projectStatus.label),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          p.cost.toVND(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          p.toBuy == 0
                              ? "Đủ linh kiện"
                              : "Cần mua thêm ~${p.toBuy.toVND()}",
                          style: TextStyle(
                            fontSize: 11,
                            color: p.toBuy == 0
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LowStockCard extends ConsumerWidget {
  final DashboardData data;

  const _LowStockCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      title: "Sắp hết / hết hàng",
      icon: Icons.inventory_2_outlined,
      child: data.lowStock.isEmpty
          ? _empty
          : Column(
              children: [
                for (final v in data.lowStock.take(12))
                  _LowStockTile(variant: v),
              ],
            ),
    );
  }
}

class _LowStockTile extends ConsumerWidget {
  final ComponentVariant variant;

  const _LowStockTile({required this.variant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final component = variant.component.target;
    final color = variant.isOut ? AppColors.error : AppColors.warning;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: ComponentThumbnail.of(component, size: 32),
      title: Text(
        component?.name ?? "",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (!variant.isDefault) variant.labelFor(component?.attributes),
          if (variant.location.isNotEmpty) variant.location,
        ].join(" · "),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: component == null
          ? null
          : () => VariantAction.showEdit(context, ref, component, variant),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          variant.isOut ? "Hết hàng" : "Còn ${variant.stock}",
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PriceIncreaseCard extends StatelessWidget {
  final DashboardData data;

  const _PriceIncreaseCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title:
          "Giá tăng mạnh (≥ ${(DashboardService.bigIncrease * 100).round()}%)",
      icon: Icons.trending_up,
      child: data.priceIncreases.isEmpty
          ? _empty
          : Column(
              children: [
                for (final i in data.priceIncreases.take(10))
                  _OptionTile(
                    insight: i,
                    trailing: Text(
                      i.trendLabel!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    detail: i.trendTooltip ?? "",
                  ),
              ],
            ),
    );
  }
}

class _StalePriceCard extends StatelessWidget {
  final DashboardData data;

  const _StalePriceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: "Giá lâu chưa kiểm tra",
      icon: Icons.schedule,
      child: data.stalePrices.isEmpty
          ? _empty
          : Column(
              children: [
                for (final i in data.stalePrices.take(10))
                  _OptionTile(
                    insight: i,
                    detail:
                        "${i.option.pricePerUnit.toVND()}/cái · ${i.staleLabel}",
                    trailing: null,
                  ),
              ],
            ),
    );
  }
}

/// 1 tuỳ chọn mua hàng kèm nút mở link + xác nhận giá.
class _OptionTile extends ConsumerWidget {
  final PriceInsight insight;
  final String detail;
  final Widget? trailing;

  const _OptionTile({
    required this.insight,
    required this.detail,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final option = insight.option;
    final component = option.component.target;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: ComponentThumbnail.of(component, size: 32),
      title: Text(
        [component?.name ?? "", option.displayName].join(" · "),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?trailing,
          if (option.link.isNotEmpty)
            IconButton(
              tooltip: "Mở link shop",
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () => launchUrl(
                Uri.parse(option.link),
                mode: LaunchMode.externalApplication,
              ),
            ),
          IconButton(
            tooltip: "Giá vẫn vậy (đã kiểm tra hôm nay)",
            icon: const Icon(Icons.check_circle_outline, size: 18),
            onPressed: () =>
                ComponentOptionAction.confirmPrice(context, ref, option),
          ),
        ],
      ),
    );
  }
}

class _CategoryValueCard extends StatelessWidget {
  final DashboardData data;

  const _CategoryValueCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final max = data.valueByCategory.isEmpty
        ? 1.0
        : data.valueByCategory.first.value;
    return _Card(
      title: "Giá trị kho theo danh mục",
      icon: Icons.pie_chart_outline,
      child: data.valueByCategory.isEmpty
          ? _empty
          : Column(
              children: [
                for (final c in data.valueByCategory.take(10))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 170,
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) => Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 14,
                                width: constraints.maxWidth * c.value / max,
                                decoration: BoxDecoration(
                                  color: Color(c.color),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            c.value.toVND(),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
