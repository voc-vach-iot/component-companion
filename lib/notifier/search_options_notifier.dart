import 'package:component_companion/data/app_setting_repository.dart';
import 'package:component_companion/model/search_params/search_options.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_options_notifier.g.dart';

/// Tuỳ chọn tìm kiếm dùng chung cho mọi ô tìm kiếm, được lưu lại giữa các lần mở app.
@Riverpod(keepAlive: true)
class SearchOptionsNotifier extends _$SearchOptionsNotifier {
  static const _settingKey = "search_options";

  @override
  SearchOptions build() {
    final json = ref.read(appSettingRepositoryProvider).get(_settingKey);
    if (json == null) return const SearchOptions();
    try {
      return SearchOptions.fromJson(json);
    } catch (_) {
      return const SearchOptions();
    }
  }

  void update(SearchOptions options) {
    state = options;
    ref.read(appSettingRepositoryProvider).set(_settingKey, options.toJson());
  }
}
