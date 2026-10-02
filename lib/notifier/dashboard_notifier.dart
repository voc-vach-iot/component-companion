import 'package:component_companion/service/dashboard_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_notifier.g.dart';

@riverpod
Stream<DashboardData> watchDashboard(Ref ref) => DashboardService().watch();
