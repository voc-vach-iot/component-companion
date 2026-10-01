import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/constant/app_svgs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Hiển thị icon từ chuỗi SVG. Chuỗi rỗng hoặc SVG lỗi => dùng [fallbackSvg].
///
/// - [color]: giá trị `currentColor` (icon kiểu Lucide dùng stroke="currentColor").
/// - [tint]: ép toàn bộ icon về 1 màu [color] (hữu ích với icon Font Awesome
///   không khai báo fill, mặc định sẽ là màu đen).
class AppSvgIcon extends StatelessWidget {
  final String svg;
  final double size;
  final Color? color;
  final bool tint;
  final String fallbackSvg;

  const AppSvgIcon({
    super.key,
    required this.svg,
    this.size = 24,
    this.color,
    this.tint = false,
    this.fallbackSvg = AppSvgs.box,
  });

  /// Kiểm tra sơ bộ chuỗi có phải SVG hay không (không parse đầy đủ).
  static bool looksLikeSvg(String value) {
    final text = value.trim().toLowerCase();
    return text.contains("<svg") && text.contains("</svg>");
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textMain;
    final source = looksLikeSvg(svg) ? svg : fallbackSvg;

    return SizedBox.square(
      dimension: size,
      child: SvgPicture.string(
        source,
        width: size,
        height: size,
        fit: BoxFit.contain,
        theme: SvgTheme(currentColor: effectiveColor),
        colorFilter: tint
            ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
            : null,
        errorBuilder: (context, error, stackTrace) => SvgPicture.string(
          fallbackSvg,
          width: size,
          height: size,
          theme: SvgTheme(currentColor: effectiveColor),
        ),
      ),
    );
  }
}
