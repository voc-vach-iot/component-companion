import 'dart:io';

import 'package:component_companion/page/category_page.dart';
import 'package:component_companion/route/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppRouteConfig {
  static final List<AppRouteItem> mainMenuItems = [
    // Định nghĩa các trang menu tại đây
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
      content: const Text("Bạn có chắc chắn muốn đóng ứng dụng?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            enabledMouseCursor: SystemMouseCursors.click,
          ),
          child: const Text("Hủy"),
        ),
        TextButton(
          onPressed: () {
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
              exit(0); // Lệnh thoát mạnh mẽ cho Desktop
            } else {
              SystemNavigator.pop(); // Dành cho Mobile
            }
          }, // Thoát app sạch sẽ
          style: TextButton.styleFrom(
            enabledMouseCursor: SystemMouseCursors.click,
          ),
          child: const Text("Thoát", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
