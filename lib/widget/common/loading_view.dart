import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';

class AppLoadingView extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const AppLoadingView({
    super.key,
    this.size = 40.0,
    this.strokeWidth = 4.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: color != null
              ? AlwaysStoppedAnimation<Color>(color ?? AppColors.primary)
              : null,
        ),
      ),
    );
  }
}
