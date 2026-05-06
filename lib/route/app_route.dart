import 'package:component_companion/route/app_route_config.dart';
import 'package:component_companion/screen/main_screen.dart';
import 'package:go_router/go_router.dart';

// Biến này chính là appRouter mà bạn cần import vào main.dart
final appRouter = GoRouter(
  initialLocation: "/project", // Hoặc path mặc định của bạn
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) =>
          "/project", // Chuyển hướng đến trang mặc định khi truy cập '/'
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainScreen(navigationShell: navigationShell),
      branches: AppRouteConfig.mainMenuItems
          .where((item) => item.path != null)
          .map((item) => StatefulShellBranch(routes: [item.toGoRoute()!]))
          .toList(),
    ),
  ],
);
