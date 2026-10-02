import 'package:component_companion/extension/objectbox/query_builder.dart';
import 'package:component_companion/model/entities/app_setting.dart';
import 'package:component_companion/objectbox.g.dart';
import 'package:component_companion/service/objectbox_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_setting_repository.g.dart';

@riverpod
AppSettingRepository appSettingRepository(Ref ref) => AppSettingRepository();

/// Lưu cấu hình dạng key-value.
class AppSettingRepository {
  final _box = ObjectboxService.instance.get<AppSetting>();

  String? get(String key) =>
      _box.query(AppSetting_.key.equals(key)).findFirstAndClose()?.value;

  // @Unique(onConflict: replace) trên key => put sẽ ghi đè bản ghi cũ
  void set(String key, String value) =>
      _box.put(AppSetting(key: key, value: value));
}
