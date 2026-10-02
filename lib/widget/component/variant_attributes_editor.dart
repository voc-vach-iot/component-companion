import 'package:component_companion/constant/app_colors.dart';
import 'package:component_companion/model/variant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Soạn các thuộc tính biến thể của linh kiện, VD:
///   Điện dung: [0.1uF] [1uF] [10uF]
///   Điện áp:   [16V] [25V]
///
/// - Bấm vào giá trị để sửa, kéo thả để đổi chỗ, ↑ ↓ để đổi thứ tự thuộc tính.
/// - Giá trị mới được chèn đúng chỗ nếu danh sách đang theo thứ tự tăng dần.
/// - Đổi tên thuộc tính / giá trị: biến thể đang dùng tên cũ đi theo tên mới
///   (báo qua [AttributeRenames]).
class VariantAttributesEditor extends HookWidget {
  final List<VariantAttribute> initial;
  final void Function(
    List<VariantAttribute> attributes,
    AttributeRenames renames,
  )
  onChanged;

  /// Tên thuộc tính gợi ý (từ loại linh kiện), VD ["Chiều dài", "Kiểu"].
  final List<String> suggestions;

  /// Số biến thể đang dùng mỗi giá trị (theo tên ban đầu): thuộc tính ->
  /// giá trị -> số biến thể. Dùng để hỏi lại khi xoá.
  final Map<String, Map<String, int>> usage;

  const VariantAttributesEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.suggestions = const [],
    this.usage = const {},
  });

  @override
  Widget build(BuildContext context) {
    // Mỗi dòng có key riêng để giữ state ô nhập khi thêm/xoá/đổi chỗ dòng
    final rows = useState<List<_Row>>([
      for (final a in initial)
        _Row(UniqueKey(), a.name, a.name, [
          for (final v in a.values) _Value(v, v),
        ]),
    ]);

    void emit() {
      final attributes = [
        for (final r in rows.value)
          if (r.name.trim().isNotEmpty && r.values.isNotEmpty)
            VariantAttribute(r.name.trim(), [
              for (final v in r.values) v.value,
            ]),
      ];
      final attributeRenames = <String, String>{};
      final valueRenames = <String, Map<String, String>>{};
      for (final r in rows.value) {
        final origin = r.origin;
        if (origin == null) continue;
        if (r.name.trim().isNotEmpty && r.name.trim() != origin) {
          attributeRenames[origin] = r.name.trim();
        }
        final renamed = {
          for (final v in r.values)
            if (v.origin != null && v.origin != v.value) v.origin!: v.value,
        };
        if (renamed.isNotEmpty) valueRenames[origin] = renamed;
      }
      onChanged(
        attributes,
        AttributeRenames(attributes: attributeRenames, values: valueRenames),
      );
    }

    void update(void Function(List<_Row> rows) change) {
      final next = [...rows.value];
      change(next);
      rows.value = next;
      emit();
    }

    final usedNames = rows.value
        .map((r) => r.name.trim().toLowerCase())
        .toSet();
    final unusedSuggestions = suggestions
        .where((s) => !usedNames.contains(s.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Biến thể (thuộc tính)",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  update((r) => r.add(_Row(UniqueKey(), null, "", []))),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text("Thêm thuộc tính"),
            ),
          ],
        ),
        const Text(
          "VD: Điện dung (0.1uF, 1uF), Điện áp (16V, 25V). Bấm vào giá trị để sửa, "
          "kéo thả để đổi chỗ. Thông số chính nên đặt lên đầu.",
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        if (unusedSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                "Gợi ý:",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              for (final name in unusedSuggestions)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 14),
                  label: Text(name, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      update((r) => r.add(_Row(UniqueKey(), null, name, []))),
                ),
            ],
          ),
        ],
        for (var i = 0; i < rows.value.length; i++)
          Padding(
            key: rows.value[i].key,
            padding: const EdgeInsets.only(top: 10),
            child: _AttributeRow(
              row: rows.value[i],
              usage: usage[rows.value[i].origin] ?? const {},
              canMoveUp: i > 0,
              canMoveDown: i < rows.value.length - 1,
              onMove: (delta) => update((r) {
                final row = r.removeAt(i);
                r.insert(i + delta, row);
              }),
              onNameChanged: (name) {
                rows.value[i].name = name;
                emit();
              },
              onValuesChanged: (values) => update(
                (r) => r[i] = _Row(r[i].key, r[i].origin, r[i].name, values),
              ),
              onRemove: () => update((r) => r.removeAt(i)),
            ),
          ),
      ],
    );
  }
}

class _Row {
  final Key key;

  /// Tên lúc mở dialog (null = thuộc tính mới thêm).
  final String? origin;
  String name;
  final List<_Value> values;

  _Row(this.key, this.origin, this.name, this.values);
}

class _Value {
  /// Giá trị lúc mở dialog (null = giá trị mới thêm).
  final String? origin;
  final String value;

  const _Value(this.origin, this.value);
}

class _AttributeRow extends HookWidget {
  final _Row row;
  final Map<String, int> usage;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<int> onMove;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<List<_Value>> onValuesChanged;
  final VoidCallback onRemove;

  const _AttributeRow({
    required this.row,
    required this.usage,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    required this.onNameChanged,
    required this.onValuesChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController(text: row.name);
    final valueController = useTextEditingController();
    final valueFocus = useFocusNode();
    final error = useState<String?>(null);

    final labels = [for (final v in row.values) v.value];
    final sorted = Variants.isSorted(labels);

    bool exists(String value, {int except = -1}) {
      for (var i = 0; i < row.values.length; i++) {
        if (i != except &&
            row.values[i].value.toLowerCase() == value.toLowerCase()) {
          return true;
        }
      }
      return false;
    }

    void addValues(String raw) {
      final next = [...row.values];
      // Đang theo thứ tự tăng dần (hoặc chưa có gì) => chèn đúng chỗ
      final keepSorted = Variants.isSorted([for (final v in next) v.value]);
      final duplicates = <String>[];
      for (final part in raw.split(",")) {
        final value = part.trim();
        if (value.isEmpty) continue;
        if (next.any((v) => v.value.toLowerCase() == value.toLowerCase())) {
          duplicates.add(value);
          continue;
        }
        final index = keepSorted
            ? next.indexWhere((v) => Variants.compareValues(value, v.value) < 0)
            : -1;
        next.insert(index < 0 ? next.length : index, _Value(null, value));
      }
      error.value = duplicates.isEmpty
          ? null
          : "Đã có: ${duplicates.join(", ")}";
      valueController.clear();
      if (next.length != row.values.length) onValuesChanged(next);
      valueFocus.requestFocus();
    }

    Future<void> editValue(int index) async {
      final current = row.values[index];
      final edited = await showDialog<String>(
        context: context,
        builder: (_) => _EditValueDialog(
          initial: current.value,
          validator: (v) => v.isEmpty
              ? "Không được để trống"
              : exists(v, except: index)
              ? "Đã có giá trị '$v'"
              : null,
        ),
      );
      if (edited == null || edited == current.value) return;
      final next = [...row.values];
      next[index] = _Value(current.origin, edited);
      onValuesChanged(next);
    }

    Future<void> removeValue(int index) async {
      final value = row.values[index];
      final used = value.origin == null ? 0 : usage[value.origin] ?? 0;
      if (used > 0) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.background,
            title: Text("Xoá giá trị '${value.value}'?"),
            content: Text(
              "$used biến thể đang dùng giá trị này. Khi lưu, chúng sẽ được gộp "
              "vào giá trị đầu tiên còn lại (cộng dồn tồn kho). Nếu chỉ muốn "
              "sửa cách viết, hãy bấm vào giá trị để sửa thay vì xoá.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Huỷ"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  "Vẫn xoá",
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }
      onValuesChanged([...row.values]..removeAt(index));
    }

    void moveValue(int from, int to) {
      if (from == to) return;
      final next = [...row.values];
      final value = next.removeAt(from);
      next.insert(to > from ? to - 1 : to, value);
      onValuesChanged(next);
    }

    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: AppColors.border),
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Đổi thứ tự thuộc tính ---
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SmallIcon(
                icon: Icons.keyboard_arrow_up_rounded,
                tooltip: "Đưa thuộc tính lên",
                onPressed: canMoveUp ? () => onMove(-1) : null,
              ),
              _SmallIcon(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: "Đưa thuộc tính xuống",
                onPressed: canMoveDown ? () => onMove(1) : null,
              ),
            ],
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 140,
            child: TextField(
              controller: nameController,
              onChanged: onNameChanged,
              decoration: const InputDecoration(
                isDense: true,
                hintText: "Tên (VD: Điện dung)",
                border: border,
                enabledBorder: border,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: valueController,
                  focusNode: valueFocus,
                  onChanged: (v) {
                    if (v.endsWith(",")) addValues(v);
                  },
                  onSubmitted: addValues,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "Giá trị rồi Enter (VD: 0.1uF, 1uF)",
                    border: border,
                    enabledBorder: border,
                    errorText: error.value,
                    suffixIcon: IconButton(
                      tooltip: "Thêm giá trị",
                      icon: const Icon(Icons.add_rounded, size: 18),
                      onPressed: () => addValues(valueController.text),
                    ),
                  ),
                ),
                if (row.values.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < row.values.length; i++)
                        _DraggableValue(
                          key: ValueKey(("value", row.values[i].value)),
                          index: i,
                          label: row.values[i].value,
                          renamedFrom:
                              row.values[i].origin != null &&
                                  row.values[i].origin != row.values[i].value
                              ? row.values[i].origin
                              : null,
                          onTap: () => editValue(i),
                          onDelete: () => removeValue(i),
                          onDrop: (from) => moveValue(from, i),
                        ),
                      // Thả vào cuối danh sách
                      _EndDropTarget(
                        onDrop: (from) => moveValue(from, row.values.length),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: sorted
                    ? "Đã theo thứ tự tăng dần"
                    : "Sắp xếp tăng dần (hiểu 0.1uF < 0.22uF < 1uF, 1K < 10K)",
                icon: Icon(
                  Icons.sort_rounded,
                  size: 20,
                  color: sorted ? AppColors.textDisabled : AppColors.info,
                ),
                onPressed: sorted || row.values.length < 2
                    ? null
                    : () {
                        final next = [...row.values]
                          ..sort(
                            (a, b) => Variants.compareValues(a.value, b.value),
                          );
                        onValuesChanged(next);
                      },
              ),
              IconButton(
                tooltip: "Xoá thuộc tính",
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.actionDelete,
                ),
                onPressed: () async {
                  final used = usage.values.fold(0, (a, b) => a + b);
                  if (used > 0) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: AppColors.background,
                        title: Text("Xoá thuộc tính '${row.name}'?"),
                        content: const Text(
                          "Các biến thể chỉ khác nhau ở thuộc tính này sẽ được "
                          "gộp lại khi lưu (cộng dồn tồn kho).",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text("Huỷ"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text(
                              "Vẫn xoá",
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                  }
                  onRemove();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 1 giá trị: bấm để sửa, kéo thả lên giá trị khác để chèn vào trước nó.
class _DraggableValue extends StatelessWidget {
  final int index;
  final String label;
  final String? renamedFrom;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<int> onDrop;

  const _DraggableValue({
    super.key,
    required this.index,
    required this.label,
    required this.renamedFrom,
    required this.onTap,
    required this.onDelete,
    required this.onDrop,
  });

  Widget _chip({bool highlighted = false}) => InputChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    tooltip: renamedFrom == null
        ? "Bấm để sửa, kéo để đổi chỗ"
        : "Đổi từ '$renamedFrom'",
    avatar: renamedFrom == null
        ? null
        : const Icon(Icons.edit_rounded, size: 12, color: AppColors.info),
    visualDensity: VisualDensity.compact,
    backgroundColor: highlighted
        ? AppColors.info.withValues(alpha: 0.2)
        : AppColors.surfaceVariant,
    side: highlighted
        ? const BorderSide(color: AppColors.info)
        : BorderSide.none,
    deleteIcon: const Icon(Icons.close_rounded, size: 14),
    onPressed: onTap,
    onDeleted: onDelete,
  );

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vạch báo vị trí chèn
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: hovering ? 3 : 0,
              height: 28,
              margin: EdgeInsets.only(right: hovering ? 4 : 0),
              color: AppColors.info,
            ),
            Draggable<int>(
              data: index,
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(opacity: 0.85, child: _chip(highlighted: true)),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: _chip()),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: _chip(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EndDropTarget extends StatelessWidget {
  final ValueChanged<int> onDrop;

  const _EndDropTarget({required this.onDrop});

  @override
  Widget build(BuildContext context) => DragTarget<int>(
    onAcceptWithDetails: (details) => onDrop(details.data),
    builder: (context, candidates, _) => AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: candidates.isEmpty ? 24 : 40,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: candidates.isEmpty
            ? null
            : Border.all(color: AppColors.info, width: 1.5),
      ),
    ),
  );
}

class _EditValueDialog extends HookWidget {
  final String initial;
  final String? Function(String value) validator;

  const _EditValueDialog({required this.initial, required this.validator});

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initial);
    final value = useValueListenable(controller).text.trim();
    final error = value == initial ? null : validator(value);

    void submit() {
      if (error != null || value.isEmpty) return;
      Navigator.pop(context, value);
    }

    return AlertDialog(
      backgroundColor: AppColors.background,
      title: const Text("Sửa giá trị"),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                isDense: true,
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Biến thể đang dùng giá trị này sẽ đổi theo, không mất tồn kho / giá.",
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Huỷ"),
        ),
        TextButton(
          onPressed: error == null && value.isNotEmpty ? submit : null,
          child: const Text("Lưu"),
        ),
      ],
    );
  }
}

class _SmallIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _SmallIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 26, height: 22),
    padding: EdgeInsets.zero,
  );
}
