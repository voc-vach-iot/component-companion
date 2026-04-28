import 'package:component_companion/constant/app_strings.dart';
import 'package:component_companion/data/category_repository.dart';
import 'package:component_companion/route/app_route.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/service/path_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PathService().init();
  await ObjectboxService.create();

  final categoryRepository = CategoryRepository();
  await categoryRepository.initDefaultCategories();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends HookWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is AssertionError &&
          details.exception.toString().contains('mouse_tracker')) {
        return; // "Câm nín" cái lỗi chuột phiền phức kia
      }
      FlutterError.presentError(details); // Các lỗi khác vẫn hiện bình thường
    };
    return MaterialApp.router(
      title: AppStrings.appName,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
    );
  }
}
