import 'dart:convert';
import 'dart:io';

import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/file_service.dart';
import 'package:component_companion/service/path_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

/// Một file sao lưu nằm trong thư mục sao lưu của app.
class BackupFile {
  final File file;
  final DateTime modifiedAt;
  final int sizeBytes;

  BackupFile(this.file, this.modifiedAt, this.sizeBytes);

  String get name => p.basename(file.path);
  bool get isAuto => name.startsWith(BackupService.autoPrefix);
}

/// Sao lưu / khôi phục toàn bộ dữ liệu ra file JSON.
///
/// - Tự động sao lưu mỗi ngày khi mở app (giữ [keepAuto] bản gần nhất).
/// - Trước khi khôi phục luôn sao lưu dữ liệu hiện tại để có thể quay lại.
class BackupService {
  static const autoPrefix = "tu-dong";
  static const beforeRestorePrefix = "truoc-khoi-phuc";
  static const keepAuto = 10;

  final _transfer = DataTransferService();

  Directory get backupDir =>
      Directory(p.join(PathService().rootPath, "backups"));

  String _encode(DataSnapshot data) =>
      const JsonEncoder.withIndent(" ").convert(data);

  /// Ghi bản sao lưu vào thư mục sao lưu của app.
  Future<File> writeLocal(String prefix) async {
    await backupDir.create(recursive: true);
    final file = File(
      p.join(backupDir.path, "${FileService.timestamped(prefix)}.json"),
    );
    await file.writeAsString(_encode(_transfer.exportAll()), flush: true);
    return file;
  }

  /// Gọi khi mở app: sao lưu nếu bản tự động gần nhất đã cũ hơn 1 ngày.
  Future<void> autoBackupIfNeeded() async {
    try {
      final autos = listLocal().where((b) => b.isAuto).toList();
      final latest = autos.isEmpty ? null : autos.first.modifiedAt;
      if (latest != null &&
          DateTime.now().difference(latest) < const Duration(hours: 20)) {
        return;
      }
      final file = await writeLocal(autoPrefix);
      debugPrint("💾 Đã tự động sao lưu: ${file.path}");

      for (final old in autos.skip(keepAuto - 1)) {
        await old.file.delete();
      }
    } catch (e) {
      // Sao lưu lỗi không được làm hỏng việc mở app
      debugPrint("⚠️ Tự động sao lưu thất bại: $e");
    }
  }

  /// Các bản sao lưu trong thư mục app, mới nhất trước.
  List<BackupFile> listLocal() {
    if (!backupDir.existsSync()) return const [];
    return backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(".json"))
        .map((f) {
          final stat = f.statSync();
          return BackupFile(f, stat.modified, stat.size);
        })
        .toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  }

  /// Xuất ra file do người dùng chọn. Trả về đường dẫn (null nếu huỷ).
  Future<String?> exportToFile() => FileService.saveText(
    dialogTitle: "Lưu file sao lưu",
    fileName: "${FileService.timestamped("component-companion")}.json",
    content: _encode(_transfer.exportAll()),
    extensions: const ["json"],
  );

  /// Đọc + kiểm tra file sao lưu (chưa ghi vào DB).
  static DataSnapshot parse(String content) {
    final Object? data;
    try {
      data = jsonDecode(content);
    } catch (_) {
      throw ValidationException("File không đúng định dạng JSON");
    }
    final error = DataTransferService.validate(data);
    if (error != null) throw ValidationException(error);
    return data as DataSnapshot;
  }

  /// Chọn file sao lưu từ máy. null nếu huỷ.
  Future<DataSnapshot?> pickFile() async {
    final picked = await FileService.pickText(
      dialogTitle: "Chọn file sao lưu",
      extensions: const ["json"],
    );
    return picked == null ? null : parse(picked.content);
  }

  Future<DataSnapshot> readLocal(BackupFile backup) async =>
      parse(await backup.file.readAsString());

  /// Thay toàn bộ dữ liệu bằng [data] (đã tự sao lưu dữ liệu hiện tại trước).
  Future<File> restore(DataSnapshot data) async {
    final safety = await writeLocal(beforeRestorePrefix);
    _transfer.replaceAll(data);
    return safety;
  }
}
