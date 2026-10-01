import 'dart:async';

// Import tất cả các model của bạn
import 'package:component_companion/model/entities/app_setting.dart';
import 'package:component_companion/model/entities/category.dart';
import 'package:component_companion/model/entities/component.dart';
import 'package:component_companion/model/entities/component_option.dart';
import 'package:component_companion/model/entities/component_type.dart';
import 'package:component_companion/model/entities/project.dart';
import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/path_service.dart';
import 'package:flutter/cupertino.dart';

class ObjectboxService {
  /// Biến static lưu trữ instance duy nhất (Singleton)
  static ObjectboxService? _instance;

  late final Store store;
  final Map<Type, Box> _boxes = {};

  /// Getter để lấy instance nhanh: ObjectBoxService.instance
  static ObjectboxService get instance {
    if (_instance == null) {
      throw Exception(
        "ObjectBoxService chưa được khởi tạo! Hãy gọi await ObjectBoxService.create() ở main.dart",
      );
    }
    return _instance!;
  }

  /// Private Constructor
  ObjectboxService._create(this.store) {
    _initBoxes();
  }

  /// Đăng ký tất cả Entity tại đây.
  /// Sau này thêm Model mới chỉ cần chạy build_runner rồi thêm 1 dòng register vào đây.
  void _initBoxes() {
    register<AppSetting>();
    register<Category>();
    register<ComponentType>();
    register<ComponentOption>();
    register<Component>();
    register<ProjectItem>();
    register<ProjectOption>();
    register<Project>();
  }

  /// Hàm đăng ký generic
  void register<T>() {
    _boxes[T] = store.box<T>();
  }

  Box<T> get<T>() => _boxes[T] as Box<T>;

  /// Gộp nhiều stream `store.watch<T>()` thành 1 stream "có thay đổi".
  /// Phát 1 sự kiện ngay khi listen (giống `triggerImmediately: true`), sau đó
  /// phát mỗi khi 1 trong các bảng được theo dõi thay đổi.
  ///
  /// Dùng khi kết quả query phụ thuộc vào dữ liệu ở bảng khác (ToOne, sort theo
  /// quan hệ, ...) mà `QueryBuilder.watch` không tự theo dõi.
  /// ```dart
  /// db.watchTables([db.store.watch<Component>(), db.store.watch<Category>()])
  ///   .map((_) => ...);
  /// ```
  Stream<void> watchTables(List<Stream<void>> tables) {
    final subscriptions = <StreamSubscription<void>>[];
    late final StreamController<void> controller;

    controller = StreamController<void>(
      onListen: () {
        controller.add(null);
        for (final table in tables) {
          subscriptions.add(
            table.listen(controller.add, onError: controller.addError),
          );
        }
      },
      onPause: () {
        for (final sub in subscriptions) {
          sub.pause();
        }
      },
      onResume: () {
        for (final sub in subscriptions) {
          sub.resume();
        }
        // Observer của store.watch<T>() huỷ đăng ký khi pause (VD: Riverpod
        // pause provider khi trang bị ẩn) => thay đổi lúc pause bị mất,
        // nên chủ động phát 1 sự kiện để query lại.
        controller.add(null);
      },
      onCancel: () async {
        await Future.wait(subscriptions.map((sub) => sub.cancel()));
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  /// Hàm khởi tạo Async (Chạy ở main.dart)
  static Future<ObjectboxService> create() async {
    // Nếu đã khởi tạo rồi thì trả về luôn (Tránh mở nhiều Store lỗi DB)
    if (_instance != null) return _instance!;

    final String customPath = PathService().databasePath;
    debugPrint("ObjectBox Path chuẩn: $customPath");
    final store = await openStore(directory: customPath);

    _instance = ObjectboxService._create(store);
    return _instance!;
  }

  /// Đóng store khi cần (Thường dùng trong Unit Test hoặc khi thoát App hoàn toàn)
  void dispose() {
    store.close();
  }
}
