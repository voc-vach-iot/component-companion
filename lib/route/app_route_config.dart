import 'dart:io';

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/page/category_page.dart';
import 'package:component_companion/page/component_page.dart';
import 'package:component_companion/route/types.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppRouteConfig {
  static final List<AppRouteItem> mainMenuItems = [
    // Định nghĩa các trang menu tại đây
    AppRouteItem(
      title: 'Component',
      icon: Icons.extension_rounded,
      path: '/component',
      builder: (context) => const ComponentPage(),
    ),
    AppRouteItem(
      title: 'Category',
      icon: Icons.category_rounded,
      path: '/category', // Đảm bảo path này khớp với logic của bạn
      builder: (context) => const CategoryPage(),
    ),

    // Nút thoát (Action item) - Sẽ bị .whereType<GoRoute>() lọc bỏ
    AppRouteItem(
      title: 'Thoát',
      icon: Icons.logout_rounded,
      onTap: (context) {
        // Gọi hàm xử lý thoát từ utils.dart hoặc hiện Dialog tại đây
        _showExitDialog(context);
      },
    ),
  ];
}

void _showExitDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Xác nhận thoát"),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: const Text("Bạn có chắc chắn muốn đóng ứng dụng?"),
      actions: [
        AppButton(
          label: "Hủy",
          variant: ButtonVariant.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label: "Thoát",
          variant: ButtonVariant.danger,
          onPressed: () {
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
              exit(0); // Lệnh thoát mạnh mẽ cho Desktop
            } else {
              SystemNavigator.pop(); // Dành cho Mobile
            }
          }, // Thoát app sạch sẽ
        ),
      ],
    ),
  );
}
