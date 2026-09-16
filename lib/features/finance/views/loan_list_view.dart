import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/finance/controllers/finance_controller.dart';
import 'package:bike_showroom_management_system/features/finance/models/loan_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Finance agreements placed at the active showroom.
class LoanListView extends GetView<LoanController> {
  const LoanListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Loans',
    actions: <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: AppButton.ghost(
          label: 'Companies',
          icon: Icons.account_balance_outlined,
          size: AppButtonSize.small,
          onPressed: () => Get.toNamed(AppRoutes.financeCompanies),
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
              () => AppAsyncBuilder<LoanModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No loans yet',
                        message:
                            'A loan and its repayment schedule are created '
                            'with a financed sale.',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<LoanModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: (LoanModel loan) =>
                            Get.toNamed(AppRoutes.loanDetails, arguments: loan),
                        mobileCardBuilder:
                            (BuildContext context, LoanModel loan) =>
                                _LoanCard(loan: loan),
                        columns: <AppDataColumn<LoanModel>>[
                          AppDataColumn<LoanModel>(
                            label: 'Loan',
                            sortKey: 'loan_number',
                            cellBuilder: (_, LoanModel l) => Text(l.loanNumber),
                          ),
                          AppDataColumn<LoanModel>(
                            label: 'Customer',
                            cellBuilder: (_, LoanModel l) =>
                                Text(l.customerName ?? '-'),
                          ),
                          AppDataColumn<LoanModel>(
                            label: 'Financier',
                            cellBuilder: (_, LoanModel l) =>
                                Text(l.financeCompanyName ?? '-'),
                          ),
                          AppDataColumn<LoanModel>(
                            label: 'Principal',
                            sortKey: 'loan_amount',
                            numeric: true,
                            cellBuilder: (_, LoanModel l) =>
                                Text(l.formattedLoanAmount),
                          ),
                          AppDataColumn<LoanModel>(
                            label: 'EMI',
                            sortKey: 'emi_amount',
                            numeric: true,
                            cellBuilder: (_, LoanModel l) =>
                                Text(l.formattedEmi),
                          ),
                          AppDataColumn<LoanModel>(
                            label: 'Tenure',
                            numeric: true,
                            cellBuilder: (_, LoanModel l) =>
                                Text('${l.tenureMonths} m'),
                          ),
                          AppDataColumn<LoanModel>(
                            label: 'Status',
                            sortKey: 'status',
                            cellBuilder: (_, LoanModel l) =>
                                AppStatusChip(status: l.status.value),
                          ),
                        ],
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

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final LoanController controller = Get.find<LoanController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 300,
          child: AppSearchField(
            hint: 'Search by loan number',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 220,
          child: Obx(
            () => AppDropdown<LoanStatus>(
              label: 'Status',
              hint: 'All',
              items: LoanStatus.values,
              itemLabel: (LoanStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});

  final LoanModel loan;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => Get.toNamed(AppRoutes.loanDetails, arguments: loan),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                loan.loanNumber,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: loan.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${loan.customerName ?? "-"} - ${loan.financeCompanyName ?? "-"}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Text(
          '${loan.formattedEmi} x ${loan.tenureMonths} months',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
  );
}
