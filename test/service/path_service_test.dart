import 'dart:io';

import 'package:component_companion/service/path_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test("chuyển thư mục giữa 2 ổ đĩa khác nhau (chép rồi xoá)", () async {
    // /tmp và thư mục build của dự án thường nằm trên 2 filesystem khác nhau
    final source = await Directory.systemTemp.createTemp("cc_move_src_");
    final targetParent = await Directory(
      p.join(Directory.current.path, "build", "test_tmp"),
    ).create(recursive: true);
    final target = p.join(targetParent.path, "moved_${source.hashCode}");

    await File(p.join(source.path, "data.mdb")).writeAsString("db");
    await Directory(p.join(source.path, "sub")).create();
    await File(p.join(source.path, "sub", "a.json")).writeAsString("{}");

    await PathService.moveDirectory(source, target);

    expect(await source.exists(), isFalse);
    expect(await File(p.join(target, "data.mdb")).readAsString(), "db");
    expect(await File(p.join(target, "sub", "a.json")).readAsString(), "{}");
    await Directory(target).delete(recursive: true);
  });
}
