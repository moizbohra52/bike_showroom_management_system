import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
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
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/sales/controllers/sale_controller.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Sales raised at the active showroom.
class SaleListView extends GetView<SaleController> {
  const SaleListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Sales',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.salesCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'New Sale',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: _openCreate,
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
              () => AppAsyncBuilder<SaleModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No sales yet',
                        message:
                            'A sale allocates a unit from stock, raises the '
                            'invoice and posts the accounting in one step.',
                        icon: Icons.receipt_long_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<SaleModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: _openDetails,
                        mobileCardBuilder:
                            (BuildContext context, SaleModel sale) =>
                                _SaleCard(sale: sale),
                        columns: <AppDataColumn<SaleModel>>[
                          AppDataColumn<SaleModel>(
                            label: 'Sale',
                            sortKey: 'sale_number',
                            cellBuilder: (_, SaleModel s) => Text(s.saleNumber),
                          ),
                          AppDataColumn<SaleModel>(
                            label: 'Date',
                            sortKey: 'sale_date',
                            cellBuilder: (_, SaleModel s) =>
                                Text(s.formattedDate),
                          ),
                          AppDataColumn<SaleModel>(
                            label: 'Customer',
                            cellBuilder: (_, SaleModel s) =>
                                Text(s.customerName ?? '-'),
                          ),
                          AppDataColumn<SaleModel>(
                            label: 'Type',
                            sortKey: 'sale_type',
                            cellBuilder: (_, SaleModel s) =>
                                Text(s.saleType.label),
                          ),
                          AppDataColumn<SaleModel>(
                            label: 'Total',
                            sortKey: 'total_amount',
                            numeric: true,
                            cellBuilder: (_, SaleModel s) =>
                                Text(s.formattedTotal),
                          ),
                          AppDataColumn<SaleModel>(
                            label: 'Outstanding',
                            sortKey: 'outstanding_amount',
                            numeric: true,
                            cellBuilder: (BuildContext context, SaleModel s) =>
                                Text(
                                  s.formattedOutstanding,
                                  style: s.outstandingAmount > 0.01
                                      ? const TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                        )
                                      : null,
                                ),
                          ),
                          AppDataColumn<SaleModel>(
                            label: 'Status',
                            sortKey: 'status',
                            cellBuilder: (_, SaleModel s) =>
                                AppStatusChip(status: s.status.value),
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
    floatingActionButton: context.isCompact
        ? AppPermissionView(
            permission: AppPermissions.salesCreate,
            child: FloatingActionButton(
              onPressed: _openCreate,
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );

  static Future<void> _openCreate() async {
    final Object? result = await Get.toNamed(AppRoutes.saleCreate);
    if (result is SaleTransactionResult) {
      await Get.find<SaleController>().reload();
    }
  }

  static Future<void> _openDetails(SaleModel sale) async {
    await Get.toNamed(AppRoutes.saleDetails, arguments: sale);
    // The details screen can cancel the sale, which changes the row.
    await Get.find<SaleController>().reload();
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final SaleController controller = Get.find<SaleController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 280,
          child: AppSearchField(
            hint: 'Search by sale number',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 200,
          child: Obx(
            () => AppDropdown<SaleStatus>(
              label: 'Status',
              hint: 'All',
              items: SaleStatus.values,
              itemLabel: (SaleStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: Obx(
            () => AppDropdown<SaleType>(
              label: 'Type',
              hint: 'All',
              items: SaleType.values,
              itemLabel: (SaleType t) => t.label,
              value: controller.typeFilter.value,
              onChanged: controller.filterByType,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: AppDateRangeField(
            label: 'Sale date',
            value: controller.params.value.dateRange,
            onChanged: controller.filterByDateRange,
          ),
        ),
      ],
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale});

  final SaleModel sale;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => SaleListView._openDetails(sale),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                sale.saleNumber,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: sale.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${sale.customerName ?? "Unknown"} - ${DateUtil.format(sale.saleDate)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              sale.formattedTotal,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            if (sale.outstandingAmount > 0.01)
              Text(
                '${sale.formattedOutstanding} due',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
              ),
          ],
        ),
      ],
    ),
  );
}
