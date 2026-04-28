import 'package:flutter/material.dart';

class GenericGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final double maxWidth;
  final double widthHeightRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const GenericGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.maxWidth = 250,
    this.widthHeightRatio = 1,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text("Không có dữ liệu"));
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxWidth,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: widthHeightRatio,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => itemBuilder(context, items[index]),
    );
  }
}
