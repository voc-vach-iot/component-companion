import 'package:objectbox/objectbox.dart';

extension ConditionExtension<T> on Condition<T>? {
  /// Phép AND an toàn:
  /// Nếu value hợp lệ, tạo condition mới và nối bằng & (AND).
  /// Nếu condition hiện tại đang null, nó sẽ lấy condition mới làm gốc (Init).
  Condition<T>? safeAnd<V>(V? value, Condition<T> Function(V) builder) {
    if (value == null || (value is String && value.isEmpty)) return this;
    final newCond = builder(value);
    return (this == null) ? newCond : this! & newCond;
  }

  /// Phép OR an toàn:
  /// Nếu value hợp lệ, tạo condition mới và nối bằng | (OR).
  /// Nếu condition hiện tại đang null, nó sẽ lấy condition mới làm gốc (Init).
  Condition<T>? safeOr<V>(V? value, Condition<T> Function(V) builder) {
    if (value == null || (value is String && value.isEmpty)) return this;
    final newCond = builder(value);
    return (this == null) ? newCond : this! | newCond;
  }
}

extension RelationConditionExtension<S, T> on QueryRelationToOne<S, T> {
  /// Tương đương `oneOf` cho quan hệ ToOne (ObjectBox không hỗ trợ IN trên
  /// thuộc tính quan hệ). [ids] rỗng => điều kiện không khớp bản ghi nào.
  Condition<S> anyOf(Iterable<int> ids) {
    // id luôn >= 1 nên -1 không bao giờ khớp
    if (ids.isEmpty) return equals(-1);
    return ids.map(equals).reduce((a, b) => a | b);
  }
}
