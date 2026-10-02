final _copySuffix = RegExp(r'\s*\(bản sao(?: \d+)?\)$');

/// Sinh tên cho bản sao không trùng: "X (bản sao)", "X (bản sao 2)", ...
/// Nhân bản tiếp một bản sao sẽ không bị lặp hậu tố ("X (bản sao) (bản sao)").
String nextCopyName(String name, bool Function(String candidate) exists) {
  final base = name.replaceFirst(_copySuffix, '');
  var candidate = "$base (bản sao)";
  for (var i = 2; exists(candidate); i++) {
    candidate = "$base (bản sao $i)";
  }
  return candidate;
}
