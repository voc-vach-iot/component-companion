import 'dart:io';

import 'package:component_companion/constant/app_strings.dart';
import 'package:flutter/foundation.dart'; // Import để dùng kDebugMode
import 'package:path/path.dart' as p;

class PathService {
  static final PathService _instance = PathService._internal();

  factory PathService() => _instance;

  PathService._internal();

  late final String _rootPath;

  String get databasePath => p.join(_rootPath, 'database');

  Future<void> init() async {
    final String? roamingPath = Platform.environment['APPDATA'];
    if (roamingPath == null) throw Exception("Không tìm thấy AppData");

    // Tự động chọn tên thư mục dựa trên chế độ chạy của App
    String folderName = AppStrings.appDataFolderName;
    if (kDebugMode) {
      folderName += '_Debug';
    }

    // 2. Thiết lập thư mục gốc của App dựa trên mode
    _rootPath = p.join(roamingPath, folderName);

    // 3. Danh sách các folder cần tạo sẵn
    final foldersToCreate = [_rootPath, databasePath];

    // 4. Tạo tất cả một lượt
    for (var path in foldersToCreate) {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        debugPrint("📁 Đã tạo thư mục [$folderName]: $path");
      }
    }
  }
}
