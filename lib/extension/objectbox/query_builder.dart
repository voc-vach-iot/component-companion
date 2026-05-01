import 'package:objectbox/objectbox.dart';

extension QueryBuilderExt<T> on QueryBuilder<T> {
  // Kết thúc query: Build -> Lấy ID -> Close (Tất cả trong 1 nốt nhạc)
  List<int> getIdsAndClose() {
    final query = build();
    try {
      return query.findIds();
    } finally {
      query.close();
    }
  }

  /// 2. RELATION XUÔI - ToOne (Ví dụ: Order -> User)
  QueryBuilder<T> safeLink<Target, V>(
    V? value,
    QueryRelationToOne<T, Target> rel,
    Condition<Target> Function(V) builder,
  ) {
    if (value == null || (value is String && value.isEmpty)) return this;
    return this..link(rel, builder(value));
  }

  /// 3. RELATION XUÔI - ToMany (Ví dụ: User -> Orders)
  QueryBuilder<T> safeLinkMany<Target, V>(
    V? value,
    QueryRelationToMany<T, Target> rel,
    Condition<Target> Function(V) builder,
  ) {
    if (value == null || (value is String && value.isEmpty)) return this;
    return this..linkMany(rel, builder(value));
  }

  /// 4. RELATION NGƯỢC - Backlink từ ToOne (Bảng khác trỏ về mình bằng ToOne)
  QueryBuilder<T> safeBacklink<Source, V>(
    V? value,
    QueryRelationToOne<Source, T> rel,
    Condition<Source> Function(V) builder,
  ) {
    if (value == null || (value is String && value.isEmpty)) return this;
    return this..backlink(rel, builder(value));
  }

  /// 5. RELATION NGƯỢC - Backlink từ ToMany (Bảng khác trỏ về mình bằng ToMany)
  QueryBuilder<T> safeBacklinkMany<Source, V>(
    V? value,
    QueryRelationToMany<Source, T> rel,
    Condition<Source> Function(V) builder,
  ) {
    if (value == null || (value is String && value.isEmpty)) return this;
    return this..backlinkMany(rel, builder(value));
  }

  Stream<PageResult<T>> watchPage({required int page, required int size}) {
    return watch(triggerImmediately: true).map((query) {
      // 1. ĐẾM TỔNG SỐ BẢN GHI (Lưu ý logic)
      // CẢNH BÁO: Không được gọi query.count() ở đây vì nó sẽ bị ảnh hưởng
      // bởi limit/offset bên trên (chỉ đếm trong 1 trang).
      // Nếu bạn cần tổng số trang, hãy tạo một Query độc lập không có
      // limit/offset hoặc sử dụng biến count đã biết trước từ hệ thống.
      final totalCount = query.count();

      // 2. TÁCH RỜI CÁC THIẾT LẬP QUERY (Quan trọng)
      // Thay vì dùng Cascade operator (..limit = size..offset = ...),
      // chúng ta gán trực tiếp từng thuộc tính để đảm bảo trình biên dịch
      // thực thi tuần tự, tránh làm xung đột vùng nhớ trong objectbox.dll (Heap Corruption).
      query.limit = size;
      query.offset = page * size;

      // 3. LẤY DỮ LIỆU CỤ THỂ
      // Sau khi đã thiết lập limit và offset, query.find() sẽ chỉ trả về
      // đúng số lượng bản ghi cần thiết cho trang hiện tại.
      final items = query.find();

      return PageResult(
        items: items,
        totalItems: totalCount,
        totalPages: (totalCount / size).ceil(),
        currentPage: page,
      );
    });
  }

  Stream<List<T>> watchQuery() {
    return watch(triggerImmediately: true).map((query) => query.find());
  }

  Stream<Map<int, T>> watchQueryAsMap() {
    return watch(triggerImmediately: true).map((query) {
      final items = query.find();
      return {for (var item in items) (item as dynamic).id as int: item};
    });
  }

}

class PageResult<T> {
  final List<T> items;
  final int totalItems;
  final int totalPages;
  final int currentPage;

  PageResult({
    required this.items,
    required this.totalItems,
    required this.totalPages,
    required this.currentPage,
  });
}
