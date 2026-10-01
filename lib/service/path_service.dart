import 'dart:io';

import 'package:component_companion/constant/app_strings.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PathService {
  static final PathService _instance = PathService._internal();

  factory PathService() => _instance;

  PathService._internal();

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
      // 2. Linux: Dùng đường dẫn tiêu chuẩn (~/.local/share/...)
      final Directory appSupportDir = await getApplicationSupportDirectory();
      _rootPath = kDebugMode
          ? p.join(appSupportDir.path, '.debug')
          : appSupportDir.path;
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
}
