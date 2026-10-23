import 'package:component_companion/data/power_supply_repository.dart';
import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/data/tray_type_repository.dart';
import 'package:component_companion/model/entities/component_variant.dart';
import 'package:component_companion/model/entities/power_supply.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/model/entities/tray_type.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_notifier.g.dart';

@riverpod
Stream<List<Storage>> watchAllStorages(Ref ref) =>
    ref.watch(storageRepositoryProvider).watchAll();

@riverpod
Stream<List<StorageTray>> watchStorageTrays(Ref ref, int storageId) =>
    ref.watch(storageRepositoryProvider).watchTrays(storageId);

@riverpod
Stream<List<TrayType>> watchAllTrayTypes(Ref ref) =>
    ref.watch(trayTypeRepositoryProvider).watchAll();

@riverpod
Stream<List<PowerSupply>> watchAllPowerSupplies(Ref ref) =>
    ref.watch(powerSupplyRepositoryProvider).watchAll();

@riverpod
Stream<List<ComponentVariant>> watchUnplacedVariants(Ref ref) =>
    ref.watch(storageRepositoryProvider).watchUnplaced();
