/// Quy tắc đổi tên hàng loạt: tìm / thay (chữ thường hoặc regex) + tiền / hậu
/// tố, hoặc dựng tên theo mẫu có biến (`{old}`, `{n}`, `{dv}`...).
class RenameRule {
  final String find;
  final String replace;
  final String prefix;
  final String suffix;
  final bool regex;
  final bool caseSensitive;

  /// Dùng [template] thay cho tìm / thay.
  final bool useTemplate;
  final String template;

  const RenameRule({
    this.find = "",
    this.replace = "",
    this.prefix = "",
    this.suffix = "",
    this.regex = false,
    this.caseSensitive = false,
    this.useTemplate = false,
    this.template = "",
  });

  /// Tên mới của [old]. [vars] = giá trị cho `{tên}` trong mẫu (ngoài `{old}`).
  /// Ném [FormatException] nếu regex sai.
  String apply(String old, [Map<String, String> vars = const {}]) {
    if (useTemplate) {
      var out = template.replaceAll("{old}", old);
      for (final e in vars.entries) {
        out = out.replaceAll("{${e.key}}", e.value);
      }
      return out.trim();
    }
    var out = old;
    if (find.isNotEmpty) {
      final pattern = RegExp(
        regex ? find : RegExp.escape(find),
        caseSensitive: caseSensitive,
      );
      out = out.replaceAllMapped(pattern, (m) {
        if (!regex) return replace;
        // $1, $2... như cú pháp thay thế quen thuộc
        return replace.replaceAllMapped(RegExp(r"\$(\d)"), (g) {
          final i = int.parse(g[1]!);
          return i <= m.groupCount ? (m.group(i) ?? "") : g[0]!;
        });
      });
    }
    return "$prefix$out$suffix".trim();
  }

  /// null nếu quy tắc hợp lệ, ngược lại thông báo lỗi (regex sai).
  String? validate() {
    if (useTemplate || !regex || find.isEmpty) return null;
    try {
      RegExp(find);
      return null;
    } on FormatException catch (e) {
      return "Regex sai: ${e.message}";
    }
  }
}
