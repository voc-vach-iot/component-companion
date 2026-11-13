import 'package:component_companion/data/storage_repository.dart';
import 'package:component_companion/model/entities/storage.dart';
import 'package:component_companion/model/entities/storage_tray.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/dialog/alert_dialog.dart';
import 'package:component_companion/widget/input/search_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef CompartmentTarget = ({StorageTray tray, int index});

/// Chọn khay + ngăn đích để chuyển đồ sang. Trả null nếu huỷ.
Future<CompartmentTarget?> showCompartmentTargetDialog(
  BuildContext context,
  StorageTray from,
  int fromIndex,
) => showDialog<CompartmentTarget>(
  context: context,
  builder: (_) => _CompartmentTargetDialog(from: from, fromIndex: fromIndex),
);

class _CompartmentTargetDialog extends HookConsumerWidget {
  final StorageTray from;
  final int fromIndex;

  const _CompartmentTargetDialog({required this.from, required this.fromIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(storageRepositoryProvider);
    final storages = useMemoized(repo.all);
    final storage = useState<Storage?>(
      storages.where((s) => s.id == from.storage.targetId).firstOrNull,
    );
    final trays = useMemoized(
      () => storage.value == null
          ? <StorageTray>[]
          : repo.traysOf(storage.value!.id),
      [storage.value?.id],
    );
    final tray = useState<StorageTray?>(null);
    final index = useState(0);
    final count = tray.value?.compartmentCount ?? 1;
    final same = tray.value?.id == from.id && index.value == fromIndex;

    return AppAlertDialog(
      title: "Chuyển ngăn ${fromIndex + 1} của ${from.label}",
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (storages.length > 1) ...[
              AppSearchSelect<Storage>(
                label: "Kho",
                items: storages,
                value: storage.value,
                labelOf: (s) => s.name,
                onChanged: (s) {
                  storage.value = s;
                  tray.value = null;
                  index.value = 0;
                },
              ),
              const SizedBox(height: 12),
            ],
            AppSearchSelect<StorageTray>(
              label: "Khay đích",
              items: trays,
              value: tray.value,
              labelOf: (t) => t.label,
              subtitleOf: (t) =>
                  "${t.trayType.target?.name ?? ""} · ${t.variants.length} linh kiện",
              onChanged: (t) {
                tray.value = t;
                index.value = 0;
              },
            ),
            if (count > 1) ...[
              const SizedBox(height: 12),
              const Text("Ngăn đích"),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < count; i++)
                    ButtonSegment(value: i, label: Text("Ngăn ${i + 1}")),
                ],
                selected: {index.value.clamp(0, count - 1)},
                onSelectionChanged: (v) => index.value = v.first,
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          label: "Chuyển",
          size: ButtonSize.small,
          isDisabled: tray.value == null || same,
          onPressed: () =>
              Navigator.pop(context, (tray: tray.value!, index: index.value)),
        ),
      ],
    );
  }
}
