import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/entities/stock_log.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:component_companion/util/text_search.dart';
import 'package:component_companion/widget/common/header.dart';
import 'package:component_companion/widget/component/stock_log_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Nhật ký kho toàn bộ: mọi lần tồn kho thay đổi.
class StockLogPage extends HookWidget {
  const StockLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final query = useState("");
    final reasons = useState<Set<StockReason>>({});
    final search = useMemoized(
      () => TextSearch(
        query.value,
        const SearchOptions(caseMode: SearchCaseMode.insensitive),
      ),
      [query.value],
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader(
            title: "Nhật ký kho".toUpperCase(),
            onSearch: (v) => query.value = v,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in StockReason.values)
                FilterChip(
                  label: Text(r.label),
                  selected: reasons.value.contains(r),
                  showCheckmark: false,
                  selectedColor: AppColors.primary.withValues(alpha: 0.35),
                  backgroundColor: AppColors.background,
                  onSelected: (v) {
                    final next = {...reasons.value};
                    v ? next.add(r) : next.remove(r);
                    reasons.value = next;
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: StockLogList(
                where: (log) =>
                    (reasons.value.isEmpty ||
                        reasons.value.contains(log.stockReason)) &&
                    (query.value.trim().isEmpty ||
                        search.matches("${log.label} ${log.note}")),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
