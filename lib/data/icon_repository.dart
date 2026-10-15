import 'package:component_companion/exception/app_exception.dart';
import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:component_companion/util/keyword_matcher.dart';
import 'package:component_companion/widget/common/svg_icon.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'icon_repository.g.dart';

@riverpod
IconRepository iconRepository(Ref ref) => IconRepository();

/// Kết quả nhập bộ icon.
typedef IconImportResult = ({int added, int updated, int skipped});

class IconRepository {
  /// Bộ chứa icon người dùng tự lưu từ ô nhập SVG.
  static const userPack = "Của tôi";

  final _db = ObjectboxService.instance;
  final _box = ObjectboxService.instance.get<IconAsset>();

  /// Mọi icon, sắp theo bộ rồi tên.
  Stream<List<IconAsset>> watchAll() =>
      _db.watchTables([_db.store.watch<IconAsset>()]).map((_) => all());

  List<IconAsset> all() => _box.getAll()
    ..sort((a, b) {
      final byPack = a.pack.toLowerCase().compareTo(b.pack.toLowerCase());
      return byPack != 0
          ? byPack
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  /// Ghi các icon vào thư viện. Trùng (cùng bộ + cùng tên, không phân biệt
  /// hoa thường) => cập nhật SVG / từ khoá thay vì thêm bản mới.
  IconImportResult import(List<IconAsset> icons) {
    return _db.store.runInTransaction(TxMode.write, () {
      final existing = {for (final i in _box.getAll()) _key(i): i};
      var added = 0, updated = 0, skipped = 0;
      final toPut = <IconAsset>[];
      for (final icon in icons) {
        final key = _key(icon);
        final old = existing[key];
        if (old == null) {
          icon.id = 0;
          existing[key] = icon;
          toPut.add(icon);
          added++;
        } else if (old.svg != icon.svg ||
            old.keywords.join("|") != icon.keywords.join("|")) {
          old
            ..svg = icon.svg
            ..keywords = icon.keywords;
          if (!toPut.contains(old)) toPut.add(old);
          updated++;
        } else {
          skipped++;
        }
      }
      _box.putMany(toPut);
      return (added: added, updated: updated, skipped: skipped);
    });
  }

  /// Lưu 1 icon (thêm hoặc sửa).
  Future<int> save(IconAsset icon) async {
    icon
      ..name = icon.name.trim()
      ..pack = icon.pack.trim().isEmpty ? userPack : icon.pack.trim()
      ..keywords = KeywordMatcher.normalizeAll(icon.keywords);
    if (icon.name.isEmpty) {
      throw ValidationException("Tên icon không được để trống");
    }
    if (!AppSvgIcon.looksLikeSvg(icon.svg)) {
      throw ValidationException("Mã SVG không hợp lệ");
    }
    // So trong Dart: ObjectBox chỉ bỏ qua hoa thường với chữ ASCII ("TỤ" ≠ "tụ")
    final key = _key(icon);
    final duplicate = _box.getAll().any(
      (i) => i.id != icon.id && _key(i) == key,
    );
    if (duplicate) {
      throw EntityAlreadyExistsException(
        "Bộ '${icon.pack}' đã có icon tên '${icon.name}'",
      );
    }
    return _box.put(icon);
  }

  Future<bool> delete(int id) async => _box.remove(id);

  /// Xoá cả bộ icon, trả về số icon đã xoá.
  Future<int> deletePack(String pack) async {
    final query = _box.query(IconAsset_.pack.equals(pack)).build();
    try {
      return query.remove();
    } finally {
      query.close();
    }
  }

  List<int> idsOfPack(String pack) =>
      _box.query(IconAsset_.pack.equals(pack)).getIdsAndClose();

  static String _key(IconAsset i) =>
      "${i.pack.trim().toLowerCase()}\u0000${i.name.trim().toLowerCase()}";
}
