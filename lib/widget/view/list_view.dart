import 'package:flutter/material.dart';

class GenericList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap; // Thêm cái này
  final ScrollPhysics? physics; // Thêm cái này để điều khiển cuộn

  const GenericList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text("Không có dữ liệu"));
    }

    return ListView.separated(
      padding: padding,
      itemCount: items.length,
      shrinkWrap: shrinkWrap, // Sử dụng shrinkWrap
      physics: physics, // Sử dụng physics
      separatorBuilder: (context, index) => SizedBox(height: spacing),
      itemBuilder: (context, index) => itemBuilder(context, items[index]),
    );
  }
}
