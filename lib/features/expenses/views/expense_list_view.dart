import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dialog.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/expenses/controllers/expense_controller.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Overheads recorded at the active showroom, and the approval queue.
class ExpenseListView extends GetView<ExpenseController> {
  const ExpenseListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Expenses',
    actions: <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: AppButton.ghost(
          label: 'Categories',
          icon: Icons.category_outlined,
          size: AppButtonSize.small,
          onPressed: () => Get.toNamed(AppRoutes.expenseCategories),
        ),
      ),
      AppPermissionView(
        permission: AppPermissions.expensesCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Record Expense',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: _openForm,
          ),
        ),
      ),
    ],
    body: AppContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg),
            child: _Filters(),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<ExpenseModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No expenses yet',
                        message:
                            'Record an overhead and it goes to a manager for '
                            'approval before it posts.',
                        icon: Icons.receipt_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<ExpenseModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        mobileCardBuilder:
                            (BuildContext context, ExpenseModel e) =>
                                _ExpenseCard(expense: e),
                        columns: <AppDataColumn<ExpenseModel>>[
                          AppDataColumn<ExpenseModel>(
                            label: 'Number',
                            sortKey: 'expense_number',
                            cellBuilder: (_, ExpenseModel e) =>
                                Text(e.expenseNumber),
                          ),
                          AppDataColumn<ExpenseModel>(
                            label: 'Date',
                            sortKey: 'expense_date',
                            cellBuilder: (_, ExpenseModel e) =>
                                Text(e.formattedDate),
                          ),
                          AppDataColumn<ExpenseModel>(
                            label: 'Category',
                            cellBuilder: (_, ExpenseModel e) =>
                                Text(e.categoryName ?? '-'),
                          ),
                          AppDataColumn<ExpenseModel>(
                            label: 'Vendor',
                            cellBuilder: (_, ExpenseModel e) =>
                                Text(e.vendorName ?? '-'),
                          ),
                          AppDataColumn<ExpenseModel>(
                            label: 'Total',
                            sortKey: 'total_amount',
                            numeric: true,
                            cellBuilder: (_, ExpenseModel e) =>
                                Text(e.formattedTotal),
                          ),
                          AppDataColumn<ExpenseModel>(
                            label: 'Status',
                            sortKey: 'status',
                            cellBuilder: (_, ExpenseModel e) =>
                                AppStatusChip(status: e.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, ExpenseModel e) =>
                                _RowActions(expense: e),
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
    floatingActionButton: context.isCompact
        ? AppPermissionView(
            permission: AppPermissions.expensesCreate,
            child: FloatingActionButton(
              onPressed: _openForm,
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );

  static Future<void> _openForm() async {
    final Object? result = await Get.toNamed(AppRoutes.expenseForm);
    if (result is String) {
      await Get.find<ExpenseController>().reload();
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final ExpenseController controller = Get.find<ExpenseController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 300,
          child: AppSearchField(
            hint: 'Search number, vendor or reference',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 200,
          child: Obx(
            () => AppDropdown<ExpenseStatus>(
              label: 'Status',
              hint: 'All',
              items: ExpenseStatus.values,
              itemLabel: (ExpenseStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: AppDateRangeField(
            label: 'Expense date',
            value: controller.params.value.dateRange,
            onChanged: controller.filterByDateRange,
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.expensesApprove,
          child: AppButton.ghost(
            label: 'Approval queue',
            icon: Icons.fact_check_outlined,
            size: AppButtonSize.small,
            onPressed: controller.showPendingApproval,
          ),
        ),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.expense});

  final ExpenseModel expense;

  @override
  Widget build(BuildContext context) {
    final ExpenseController controller = Get.find<ExpenseController>();

    // Separation of duties: whoever recorded the expense may not decide it.
    // The server enforces this too; hiding the buttons avoids offering an
    // action that would only be refused.
    if (!expense.canBeDecidedBy(
      controller.currentUserId,
      isSuperAdmin: controller.isSuperAdmin,
    )) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPermissionView(
          permission: AppPermissions.expensesApprove,
          child: AppIconButton(
            icon: Icons.check,
            tooltip: 'Approve',
            onPressed: () async {
              final bool confirmed = await AppDialog.confirm(
                title: 'Approve this expense?',
                message:
                    '${expense.formattedTotal} under '
                    '${expense.categoryName ?? "this category"} will post to '
                    'the ledger.',
                confirmLabel: 'Approve',
              );
              if (confirmed) {
                await controller.decide(expense: expense, approve: true);
              }
            },
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.expensesReject,
          child: AppIconButton(
            icon: Icons.close,
            tooltip: 'Reject',
            isDestructive: true,
            onPressed: () async {
              final String? reason = await AppDialog.confirmWithReason(
                title: 'Reject this expense?',
                message:
                    'The person who recorded it will see the reason you give.',
                confirmLabel: 'Reject',
              );
              if (reason != null) {
                await controller.decide(
                  expense: expense,
                  approve: false,
                  reason: reason,
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});

  final ExpenseModel expense;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                expense.categoryName ?? expense.expenseNumber,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: expense.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${expense.expenseNumber} - ${expense.formattedDate}'
          '${expense.vendorName != null ? " - ${expense.vendorName}" : ""}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (expense.isRejected && expense.rejectionReason != null) ...<Widget>[
          AppSpacing.gapXs,
          Text(
            expense.rejectionReason!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
        ],
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              expense.formattedTotal,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            _RowActions(expense: expense),
          ],
        ),
      ],
    ),
  );
}
