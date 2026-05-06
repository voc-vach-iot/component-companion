import 'package:component_companion/model/entities/project_item.dart';
import 'package:component_companion/model/entities/project_option.dart';
import 'package:component_companion/widget/button/button.dart';
import 'package:component_companion/widget/view/list_view.dart';
import 'package:component_companion/widget/view/tab/tab_content.dart';
import 'package:flutter/material.dart';

class ProjectOptionTabContent extends StatelessWidget {
  final ProjectOption option;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddItem;
  final Widget Function(ProjectItem) itemBuilder;
  const ProjectOptionTabContent({
    super.key,
    required this.option,
    required this.onAddItem,
    required this.onEdit,
    required this.onDelete,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AppTabContent(
      title: option.name,
      description: option.description,
      headerAction: Row(
        children: [
          AppButton(
            onPressed: onAddItem,
            label: "Thêm linh kiện",
            icon: Icons.add,
            variant: ButtonVariant.primary,
          ),
          const SizedBox(width: 8),
          AppButton(
            onPressed: onEdit,
            label: "Sửa",
            icon: Icons.edit,
            variant: ButtonVariant.secondary,
          ),
          const SizedBox(width: 8),
          AppButton(
            onPressed: onDelete,
            label: "Xóa",
            icon: Icons.delete,
            variant: ButtonVariant.danger,
          ),
        ],
      ),
      child: Center(
        child: GenericList(
          items: option.items,
          itemBuilder: (ctx, item) => itemBuilder(item),
        ),
      ),
    );
  }
}
