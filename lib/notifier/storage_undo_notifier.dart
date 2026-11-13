import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_undo_notifier.g.dart';

class _UndoStep {
  final String label;
  final Future<void> Function() undo;
  const _UndoStep(this.label, this.undo);
}

/// Ngăn xếp hoàn tác các thao tác sơ đồ kho (đánh số LED, dời LED, chuyển
/// ngăn), tách theo kho, tối đa [maxSteps] bước. State là số bước hiện có
/// của mỗi kho để widget rebuild khi đổi.
@Riverpod(keepAlive: true)
class StorageUndo extends _$StorageUndo {
  static const maxSteps = 30;
  final _stacks = <int, List<_UndoStep>>{};

  @override
  Map<int, int> build() => const {};

  void push(int storageId, String label, Future<void> Function() undo) {
    final stack = _stacks.putIfAbsent(storageId, () => []);
    stack.add(_UndoStep(label, undo));
    if (stack.length > maxSteps) stack.removeAt(0);
    state = {...state, storageId: stack.length};
  }

  /// Chạy bước hoàn tác gần nhất; trả nhãn, null nếu không còn bước nào.
  Future<String?> pop(int storageId) async {
    final stack = _stacks[storageId];
    if (stack == null || stack.isEmpty) return null;
    final step = stack.removeLast();
    state = {...state, storageId: stack.length};
    await step.undo();
    return step.label;
  }

  bool canUndo(int storageId) => (_stacks[storageId]?.isNotEmpty) ?? false;
}
