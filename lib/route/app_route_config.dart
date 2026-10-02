import 'dart:io';

import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/page/category_page.dart';
import 'package:component_companion/page/dashboard_page.dart';
import 'package:component_companion/page/data_page.dart';
import 'package:component_companion/page/shop_page.dart';
import 'package:component_companion/page/shopping_list_page.dart';
import 'package:component_companion/page/component_page.dart';
import 'package:component_companion/page/component_type_page.dart';
import 'package:component_companion/page/project_detail_page.dart';
import 'package:component_companion/page/project_page.dart';
import 'package:component_companion/route/types.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AppRouteConfig {
  static final List<AppRouteItem> mainMenuItems = [
    AppRouteItem(
      title: "Tổng quan",
      icon: Icons.dashboard_rounded,
      path: "/dashboard",
      builder: (context) => const DashboardPage(),
    ),
    // Định nghĩa các trang menu tại đây
    AppRouteItem(
      title: "Dự án",
      icon: Icons.folder_rounded,
      path: "/project",
      builder: (context) => const ProjectPage(),
      subRoutes: [
        AppRouteItem(
          title: "Chi tiết dự án",
          icon: Icons.folder_open_rounded,
          path: ":id",
          builder: (context) {
            final state = GoRouterState.of(context);
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return ProjectDetailPage(projectId: id);
          },
        ),
      ],
    ),
    // Đường dẫn động cho chi tiết dự án
    AppRouteItem(
      title: "Linh kiện",
      icon: Icons.extension_rounded,
      path: "/component",
      builder: (context) => const ComponentPage(),
    ),
    AppRouteItem(
      title: "Cần mua",
      icon: Icons.shopping_cart_rounded,
      path: "/shopping",
      builder: (context) {
        final query = GoRouterState.of(context).uri.queryParameters;
        final projectId = int.tryParse(query["project"] ?? "");
        // Đổi key khi mở từ dự án khác để chọn lại dự án
        return ShoppingListPage(
          key: ValueKey(projectId),
          initialProjectId: projectId,
        );
      },
    ),
    AppRouteItem(
      title: "Shop",
      icon: Icons.storefront_rounded,
      // Không dùng "/shop" vì trùng tiền tố với "/shopping" khi tô sáng menu
      path: "/stores",
      builder: (context) => const ShopPage(),
    ),
    AppRouteItem(
      title: "Danh mục",
      icon: Icons.category_rounded,
      path: "/category", // Đảm bảo path này khớp với logic của bạn
      builder: (context) => const CategoryPage(),
    ),
    AppRouteItem(
      title: "Loại linh kiện",
      icon: Icons.memory_rounded,
      path: "/type",
      builder: (context) => const ComponentTypePage(),
    ),
    AppRouteItem(
      title: "Dữ liệu",
      icon: Icons.storage_rounded,
      path: "/data",
      builder: (context) => const DataPage(),
    ),

    // Nút thoát (Action item) - Sẽ bị .whereType<GoRoute>() lọc bỏ
    AppRouteItem(
      title: "Thoát",
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
