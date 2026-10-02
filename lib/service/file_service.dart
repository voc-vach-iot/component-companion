import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Lưu / mở file văn bản qua hộp thoại hệ thống.
class FileService {
  FileService._();

  /// Hỏi nơi lưu rồi ghi [content] (UTF-8). Trả về đường dẫn, null nếu huỷ.
  static Future<String?> saveText({
    required String fileName,
    required String content,
    required List<String> extensions,
    String dialogTitle = "Lưu file",
    bool withBom = false,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (path == null) return null;

    final bytes = [
      // BOM giúp Excel đọc đúng tiếng Việt trong CSV
      if (withBom) ...[0xEF, 0xBB, 0xBF],
      ...utf8.encode(content),
    ];
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Chọn 1 file văn bản và đọc nội dung (UTF-8). null nếu huỷ.
  static Future<({String name, String content})?> pickText({
    required List<String> extensions,
    String dialogTitle = "Chọn file",
  }) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return null;

    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) return null;
    var content = utf8.decode(bytes, allowMalformed: true);
    if (content.startsWith('﻿')) content = content.substring(1);
    return (name: file.name, content: content);
  }

  /// Tên file an toàn kèm thời gian, VD "backup-20261002-1530".
  static String timestamped(String prefix, [DateTime? at]) {
    final t = at ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return "$prefix-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}";
  }
}
