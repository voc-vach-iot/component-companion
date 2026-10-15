import 'dart:convert';
import 'dart:io';

import 'package:component_companion/data/icon_repository.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/service/data_transfer_service.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

const _a = '<svg viewBox="0 0 24 24"><path d="M2 12h20"/></svg>';
const _b = '<svg viewBox="0 0 24 24"><path d="M12 2v20"/></svg>';

void main() {
  late ObjectboxService db;
  late Directory dir;

  setUp(() async => (db, dir) = await openTestDb());
  tearDown(() => closeTestDb(db, dir));

  test("nhập lại: trùng bộ + tên => cập nhật, không nhân đôi", () {
    final repo = IconRepository();
    var result = repo.import([
      IconAsset(name: "Tụ", svg: _a, pack: "P"),
      IconAsset(name: "Diode", svg: _a, pack: "P"),
    ]);
    expect(result, (added: 2, updated: 0, skipped: 0));

    result = repo.import([
      IconAsset(name: "tụ", svg: _b, pack: "p"),
      IconAsset(name: "Diode", svg: _a, pack: "P"),
      IconAsset(name: "Tụ", svg: _a, pack: "Bộ khác"),
    ]);
    expect(result, (added: 1, updated: 1, skipped: 1));
    expect(db.get<IconAsset>().count(), 3);
    expect(
      repo.all().firstWhere((i) => i.pack == "P" && i.name == "Tụ").svg,
      _b,
    );
  });

  test("lưu icon trùng tên trong bộ bị chặn, xoá cả bộ", () async {
    final repo = IconRepository();
    await repo.save(IconAsset(name: "Tụ", svg: _a, pack: "P"));
    expect(
      () => repo.save(IconAsset(name: "TỤ", svg: _b, pack: "P")),
      throwsA(anything),
    );
    expect(await repo.deletePack("P"), 1);
  });

  test("sao lưu / khôi phục giữ thư viện icon", () {
    IconRepository().import([
      IconAsset(name: "Tụ", svg: _a, pack: "P", keywords: ["tụ"]),
    ]);
    final transfer = DataTransferService();
    transfer.replaceAll(jsonDecode(jsonEncode(transfer.exportAll())));
    final icon = db.get<IconAsset>().getAll().single;
    expect((icon.name, icon.pack), ("Tụ", "P"));
    expect(icon.keywords, ["tụ"]);
  });
}
