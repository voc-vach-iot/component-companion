import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/extension/format/num.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:flutter/material.dart';

class ProjectOptionPriceCard extends StatelessWidget {
  final ProjectOption option;
  final List<ProjectItem> baseitems;

  const ProjectOptionPriceCard({
    super.key,
    required this.option,
    required this.baseitems,
  });

  @override
  Widget build(BuildContext context) {
    final basePrice = baseitems
        .map(
          (item) =>
              item.quantity * (item.componentOption.target?.pricePerUnit ?? 0),
        )
        .fold(0.0, (a, b) => a + b);
    final optionPrice = option.items
        .map(
          (item) =>
              item.quantity * (item.componentOption.target?.pricePerUnit ?? 0),
        )
        .fold(0.0, (a, b) => a + b);
    final price = basePrice + optionPrice;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              option.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            price.toVND(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
