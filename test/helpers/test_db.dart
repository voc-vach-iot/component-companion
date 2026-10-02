import 'dart:io';

import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';

/// Mở ObjectBox thật trong thư mục tạm. Cần thư viện native:
/// chạy test với LD_LIBRARY_PATH trỏ tới build/linux/x64/debug/bundle/lib
/// (sau khi `flutter build linux --debug`).
Future<(ObjectboxService, Directory)> openTestDb() async {
  final dir = await Directory.systemTemp.createTemp("cc_test_db_");
  final store = await openStore(directory: dir.path);
  return (ObjectboxService.createForTest(store), dir);
}

Future<void> closeTestDb(ObjectboxService db, Directory dir) async {
  db.dispose();
  await dir.delete(recursive: true);
}
