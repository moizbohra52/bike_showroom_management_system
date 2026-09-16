import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/billing/controllers/invoice_controller.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Tax invoices raised at the active showroom.
class InvoiceListView extends GetView<InvoiceController> {
  const InvoiceListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Billing',
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
              () => AppAsyncBuilder<InvoiceModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No invoices yet',
                        message:
                            'An invoice is raised automatically when a sale '
                            'is booked.',
                        icon: Icons.description_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<InvoiceModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: _openDetails,
                        mobileCardBuilder:
                            (BuildContext context, InvoiceModel invoice) =>
                                _InvoiceCard(invoice: invoice),
                        columns: <AppDataColumn<InvoiceModel>>[
                          AppDataColumn<InvoiceModel>(
                            label: 'Invoice',
                            sortKey: 'invoice_number',
                            cellBuilder: (_, InvoiceModel i) =>
                                Text(i.invoiceNumber),
                          ),
                          AppDataColumn<InvoiceModel>(
                            label: 'Date',
                            sortKey: 'invoice_date',
                            cellBuilder: (_, InvoiceModel i) =>
                                Text(i.formattedDate),
                          ),
                          AppDataColumn<InvoiceModel>(
                            label: 'Customer',
                            cellBuilder: (_, InvoiceModel i) =>
                                Text(i.customerName ?? '-'),
                          ),
                          AppDataColumn<InvoiceModel>(
                            label: 'Total',
                            sortKey: 'total_amount',
                            numeric: true,
                            cellBuilder: (_, InvoiceModel i) =>
                                Text(i.formattedTotal),
                          ),
                          AppDataColumn<InvoiceModel>(
                            label: 'Outstanding',
                            sortKey: 'outstanding_amount',
                            numeric: true,
                            cellBuilder:
                                (BuildContext context, InvoiceModel i) => Text(
                                  i.formattedOutstanding,
                                  style: i.outstandingAmount > 0.01
                                      ? const TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                        )
                                      : null,
                                ),
                          ),
                          AppDataColumn<InvoiceModel>(
                            label: 'Status',
                            sortKey: 'status',
                            cellBuilder: (_, InvoiceModel i) =>
                                AppStatusChip(status: i.status.value),
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

  static Future<void> _openDetails(InvoiceModel invoice) async {
    await Get.toNamed(AppRoutes.invoiceDetails, arguments: invoice);
    // A payment may have been recorded from the details screen.
    await Get.find<InvoiceController>().reload();
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final InvoiceController controller = Get.find<InvoiceController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 280,
          child: AppSearchField(
            hint: 'Search by invoice number',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 220,
          child: Obx(
            () => AppDropdown<InvoiceStatus>(
              label: 'Status',
              hint: 'All',
              items: InvoiceStatus.values,
              itemLabel: (InvoiceStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: AppDateRangeField(
            label: 'Invoice date',
            value: controller.params.value.dateRange,
            onChanged: controller.filterByDateRange,
          ),
        ),
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final InvoiceModel invoice;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => InvoiceListView._openDetails(invoice),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                invoice.invoiceNumber,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: invoice.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${invoice.customerName ?? "Unknown"} - ${invoice.formattedDate}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              invoice.formattedTotal,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            if (invoice.outstandingAmount > 0.01)
              Text(
                '${invoice.formattedOutstanding} due',
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
