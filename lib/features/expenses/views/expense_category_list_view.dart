import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/features/expenses/controllers/expense_controller.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_category_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Expense categories, each mapped to a chart-of-accounts code.
class ExpenseCategoryListView extends GetView<ExpenseCategoryController> {
  const ExpenseCategoryListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Expense Categories',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.accountingManage,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Category',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => _showEditor(controller),
          ),
        ),
      ),
    ],
    body: AppContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: SizedBox(
              width: 340,
              child: AppSearchField(
                hint: 'Search categories',
                onChanged: controller.search,
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<ExpenseCategoryModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: const AppEmptyState(
                  title: 'No categories yet',
                  message:
                      'A category decides which expense account an overhead '
                      'posts to.',
                  icon: Icons.category_outlined,
                ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<ExpenseCategoryModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        mobileCardBuilder:
                            (BuildContext context, ExpenseCategoryModel c) =>
                                _CategoryCard(category: c),
                        columns: <AppDataColumn<ExpenseCategoryModel>>[
                          AppDataColumn<ExpenseCategoryModel>(
                            label: 'Category',
                            sortKey: 'name',
                            cellBuilder: (_, ExpenseCategoryModel c) =>
                                Text(c.name),
                          ),
                          AppDataColumn<ExpenseCategoryModel>(
                            label: 'Account code',
                            cellBuilder:
                                (
                                  BuildContext context,
                                  ExpenseCategoryModel c,
                                ) => Text(
                                  c.accountCode ?? 'Not mapped',
                                  style: c.isPostable
                                      ? null
                                      : const TextStyle(
                                          color: AppColors.warning,
                                        ),
                                ),
                          ),
                          AppDataColumn<ExpenseCategoryModel>(
                            label: 'Active',
                            cellBuilder: (_, ExpenseCategoryModel c) =>
                                Text(c.isActive ? 'Yes' : 'Retired'),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, ExpenseCategoryModel c) =>
                                _RowActions(category: c),
                      ),
                    ),
                    AppPagination(
                      response: controller.response.value,
                      onPageChanged: controller.goToPage,
                      onPageSizeChanged: controller.setPageSize,
                      compact: context.isCompact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showEditor(
  ExpenseCategoryController controller, {
  ExpenseCategoryModel? existing,
}) => Get.dialog<void>(
  _CategoryDialog(controller: controller, existing: existing),
  barrierDismissible: false,
);

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.controller, this.existing});

  final ExpenseCategoryController controller;
  final ExpenseCategoryModel? existing;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.accountCode ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bool saved = await widget.controller.save(
      name: _name.text,
      accountCode: _code.text,
      existing: widget.existing,
    );
    if (saved) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add Category' : 'Edit Category'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextField(
            label: 'Name',
            controller: _name,
            isRequired: true,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          AppSpacing.gapLg,
          AppTextField.code(
            label: 'Account code',
            controller: _code,
            isRequired: false,
            maxLength: 10,
            hint: 'e.g. 5101',
            helper: 'The expense account this category posts to',
          ),
        ],
      ),
    ),
    actions: <Widget>[
      AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
      Obx(
        () => AppButton.primary(
          label: widget.existing == null ? 'Add' : 'Save',
          isLoading: widget.controller.isSaving.value,
          onPressed: _save,
        ),
      ),
    ],
  );
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.category});

  final ExpenseCategoryModel category;

  @override
  Widget build(BuildContext context) {
    final ExpenseCategoryController controller =
        Get.find<ExpenseCategoryController>();
    return AppPermissionView(
      permission: AppPermissions.accountingManage,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () => _showEditor(controller, existing: category),
          ),
          AppIconButton(
            icon: category.isActive
                ? Icons.toggle_on
                : Icons.toggle_off_outlined,
            tooltip: category.isActive ? 'Retire' : 'Restore',
            onPressed: () => controller.toggleActive(category),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final ExpenseCategoryModel category;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                category.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              AppSpacing.gapXs,
              Text(
                category.accountCode ?? 'Not mapped to an account',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: category.isPostable ? null : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        _RowActions(category: category),
      ],
    ),
  );
}
