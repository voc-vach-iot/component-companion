import 'dart:io';

import 'package:component_companion/constant/app_strings.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PathService {
  static final PathService _instance = PathService._internal();

  factory PathService() => _instance;

  PathService._internal();

  /// APPLICATION_ID trong linux/CMakeLists.txt (tên thư mục dữ liệu bản cũ).
  static const _legacyLinuxApplicationId = "com.example.component_companion";

  late final String _rootPath;
  bool _isInitialized = false;

  String get rootPath => _rootPath;

  String get databasePath => p.join(_rootPath, 'database');

  Future<void> init() async {
    if (_isInitialized) return;

    // Tự động chọn tên thư mục dựa trên chế độ chạy của App
    String folderName = AppStrings.appDataFolderName;
    if (kDebugMode) {
      folderName += '_Debug';
    }

    if (Platform.isWindows) {
      // 1. Windows: Lấy rootPath từ %APPDATA%/FolderName
      final String? roamingPath = Platform.environment['APPDATA'];
      if (roamingPath == null) throw Exception("Không tìm thấy AppData");
      _rootPath = p.join(roamingPath, folderName);
    } else if (Platform.isLinux) {
      // 2. Linux: $XDG_DATA_HOME/component-companion (mặc định ~/.local/share)
      final dataHome =
          Platform.environment['XDG_DATA_HOME'] ??
          p.join(Platform.environment['HOME'] ?? '', '.local', 'share');
      final base = p.join(dataHome, AppStrings.linuxDataFolderName);
      _rootPath = kDebugMode ? p.join(base, '.debug') : base;

      // Dữ liệu bản cũ có thể nằm ở: thư mục theo application id, hoặc
      // ~/.local/share khi app được mở từ launcher không có XDG_DATA_HOME
      final home = Platform.environment['HOME'] ?? '';
      final defaultDataHome = p.join(home, '.local', 'share');
      String modeRoot(String base) =>
          kDebugMode ? p.join(base, '.debug') : base;
      await _migrateLegacy([
        modeRoot(p.join(dataHome, _legacyLinuxApplicationId)),
        modeRoot(p.join(defaultDataHome, AppStrings.linuxDataFolderName)),
        modeRoot(p.join(defaultDataHome, _legacyLinuxApplicationId)),
      ], _rootPath);
    } else {
      // 3. Các nền tảng khác (macOS, Android, iOS, ...)
      final Directory appSupportDir = await getApplicationSupportDirectory();
      _rootPath = appSupportDir.path;
    }

    // 4. Tạo thư mục làm việc (Thư mục gốc và database)
    final foldersToCreate = [_rootPath, databasePath];
    for (var path in foldersToCreate) {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        debugPrint("📁 Đã tạo thư mục [$folderName]: $path");
      }
    }

    _isInitialized = true;
  }

  /// Chuyển database + bản sao lưu từ thư mục cũ đầu tiên có dữ liệu sang
  /// thư mục mới (chỉ khi thư mục mới chưa có database). Dọn thư mục cũ nếu trống.
  Future<void> _migrateLegacy(List<String> legacyRoots, String newRoot) async {
    if (await Directory(p.join(newRoot, 'database')).exists()) return;

    for (final legacyRoot in legacyRoots) {
      if (p.equals(legacyRoot, newRoot)) continue;
      if (!await Directory(p.join(legacyRoot, 'database')).exists()) continue;

      await Directory(newRoot).create(recursive: true);
      for (final name in const ['database', 'backups']) {
        final source = Directory(p.join(legacyRoot, name));
        if (await source.exists()) {
          await moveDirectory(source, p.join(newRoot, name));
        }
      }
      debugPrint("📦 Đã chuyển dữ liệu từ $legacyRoot sang $newRoot");

      // Dọn thư mục cũ nếu không còn gì
      for (final dir in [legacyRoot, p.dirname(legacyRoot)]) {
        final d = Directory(dir);
        if (await d.exists() && await d.list().isEmpty) await d.delete();
      }
      return;
    }
  }

  /// rename không chạy được giữa 2 ổ đĩa khác nhau => chép rồi xoá.
  @visibleForTesting
  static Future<void> moveDirectory(Directory source, String target) async {
    try {
      await source.rename(target);
    } on FileSystemException {
      await for (final entity in source.list(recursive: true)) {
        final relative = p.relative(entity.path, from: source.path);
        final destination = p.join(target, relative);
        if (entity is Directory) {
          await Directory(destination).create(recursive: true);
        } else if (entity is File) {
          await Directory(p.dirname(destination)).create(recursive: true);
          await entity.copy(destination);
        }
      }
      await source.delete(recursive: true);
    }
  }
}
