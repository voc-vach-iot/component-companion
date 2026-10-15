import 'package:component_companion/data/icon_repository.dart';
import 'package:component_companion/model/entities/icon_asset.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'icon_notifier.g.dart';

@riverpod
Stream<List<IconAsset>> watchIcons(Ref ref) =>
    ref.watch(iconRepositoryProvider).watchAll();
