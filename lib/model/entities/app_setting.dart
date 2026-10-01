import 'package:objectbox/objectbox.dart';

/// Key-value lưu cấu hình nội bộ của app (ví dụ: phiên bản dữ liệu seed).
@Entity()
class AppSetting {
  @Id()
  int id;

  @Unique(onConflict: ConflictStrategy.replace)
  String key;

  String value;

  AppSetting({this.id = 0, required this.key, this.value = ""});
}
