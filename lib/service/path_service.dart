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

      // Bản cũ lưu theo application id (path_provider) => chuyển sang chỗ mới.
      // Không gọi getApplicationSupportDirectory() vì nó tự tạo thư mục cũ.
      final legacyBase = p.join(dataHome, _legacyLinuxApplicationId);
      await _migrateLegacy(
        kDebugMode ? p.join(legacyBase, '.debug') : legacyBase,
        _rootPath,
      );
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

  /// Chuyển database + bản sao lưu từ thư mục cũ sang thư mục mới (chỉ khi
  /// thư mục mới chưa có database). Xoá thư mục cũ nếu đã trống.
  Future<void> _migrateLegacy(String legacyRoot, String newRoot) async {
    if (p.equals(legacyRoot, newRoot)) return;
    final legacyDatabase = Directory(p.join(legacyRoot, 'database'));
    final newDatabase = Directory(p.join(newRoot, 'database'));
    if (!await legacyDatabase.exists() || await newDatabase.exists()) return;

    await Directory(newRoot).create(recursive: true);
    for (final name in const ['database', 'backups']) {
      final source = Directory(p.join(legacyRoot, name));
      if (await source.exists()) {
        await source.rename(p.join(newRoot, name));
      }
    }
    debugPrint("📦 Đã chuyển dữ liệu từ $legacyRoot sang $newRoot");

    // Dọn thư mục cũ nếu không còn gì
    for (final dir in [legacyRoot, p.dirname(legacyRoot)]) {
      final d = Directory(dir);
      if (await d.exists() && await d.list().isEmpty) await d.delete();
    }
  }
}
