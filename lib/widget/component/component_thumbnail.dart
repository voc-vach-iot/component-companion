import 'dart:convert';

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/constant/app_svgs.dart';
import 'package:component_companion/extension/color/color.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:flutter/material.dart';

/// Ảnh đại diện của linh kiện, viền theo màu danh mục.
///
/// Thứ tự ưu tiên: ảnh tải lên > icon SVG riêng > icon mặc định của loại > icon chip.
class ComponentThumbnail extends StatelessWidget {
  final String base64Image;
  final String iconSvg;
  final String typeIconSvg;
  final Color? categoryColor;
  final double size;

  const ComponentThumbnail({
    super.key,
    this.base64Image = "",
    this.iconSvg = "",
    this.typeIconSvg = "",
    this.categoryColor,
    this.size = 60,
  });

  factory ComponentThumbnail.of(
    Component? component, {
    Key? key,
    Category? category,
    double size = 60,
  }) {
    return ComponentThumbnail(
      key: key,
      base64Image: component?.base64Image ?? "",
      iconSvg: component?.iconSvg ?? "",
      typeIconSvg: component?.type.target?.defaultIconSvg ?? "",
      categoryColor: (category ?? component?.category.target)?.color,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderWidth = size >= 48 ? 2.0 : 1.5;
    final radius = BorderRadius.circular(size * 0.16);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            categoryColor?.withValues(alpha: 0.25) ?? AppColors.surfaceVariant,
        borderRadius: radius,
        border: Border.all(
          color: categoryColor ?? AppColors.border,
          width: borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius - BorderRadius.circular(borderWidth),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (base64Image.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(base64Image),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Icon(Icons.broken_image)),
        );
      } catch (_) {
        return const Center(child: Icon(Icons.error));
      }
    }

    final svg = iconSvg.isNotEmpty ? iconSvg : typeIconSvg;
    final hasSvg = svg.isNotEmpty;
    return Center(
      child: AppSvgIcon(
        svg: svg,
        fallbackSvg: AppSvgs.chip,
        size: size * 0.6,
        color: hasSvg
            ? (categoryColor?.onPastel ?? AppColors.textMain)
            : AppColors.textDisabled,
      ),
    );
  }
}
