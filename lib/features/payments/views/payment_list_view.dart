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
import 'package:bike_showroom_management_system/features/payments/controllers/payment_controller.dart';
import 'package:bike_showroom_management_system/features/payments/models/payment_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Receipts recorded at the active showroom.
class PaymentListView extends GetView<PaymentController> {
  const PaymentListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Payments',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.paymentsCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Record Payment',
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
              () => AppAsyncBuilder<PaymentModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No payments yet',
                        message:
                            'Receipts appear here as money is collected '
                            'against invoices and EMIs.',
                        icon: Icons.payments_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<PaymentModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        mobileCardBuilder:
                            (BuildContext context, PaymentModel p) =>
                                _PaymentCard(payment: p),
                        columns: <AppDataColumn<PaymentModel>>[
                          AppDataColumn<PaymentModel>(
                            label: 'Receipt',
                            sortKey: 'payment_number',
                            cellBuilder: (_, PaymentModel p) =>
                                Text(p.paymentNumber),
                          ),
                          AppDataColumn<PaymentModel>(
                            label: 'Date',
                            sortKey: 'payment_date',
                            cellBuilder: (_, PaymentModel p) =>
                                Text(p.formattedDate),
                          ),
                          AppDataColumn<PaymentModel>(
                            label: 'Customer',
                            cellBuilder: (_, PaymentModel p) =>
                                Text(p.customerName ?? '-'),
                          ),
                          AppDataColumn<PaymentModel>(
                            label: 'Against',
                            cellBuilder: (_, PaymentModel p) =>
                                Text(p.invoiceNumber ?? p.allocationLabel),
                          ),
                          AppDataColumn<PaymentModel>(
                            label: 'Method',
                            sortKey: 'payment_method',
                            cellBuilder: (_, PaymentModel p) =>
                                Text(p.paymentMethod.label),
                          ),
                          AppDataColumn<PaymentModel>(
                            label: 'Amount',
                            sortKey: 'amount',
                            numeric: true,
                            cellBuilder:
                                (BuildContext context, PaymentModel p) => Text(
                                  p.formattedAmount,
                                  style: p.isReversal
                                      ? const TextStyle(color: AppColors.danger)
                                      : null,
                                ),
                          ),
                          AppDataColumn<PaymentModel>(
                            label: 'Status',
                            sortKey: 'status',
                            cellBuilder: (_, PaymentModel p) =>
                                AppStatusChip(status: p.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, PaymentModel p) =>
                                _RowActions(payment: p),
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
            permission: AppPermissions.paymentsCreate,
            child: FloatingActionButton(
              onPressed: _openForm,
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );

  static Future<void> _openForm() async {
    final Object? result = await Get.toNamed(AppRoutes.paymentForm);
    if (result is String) {
      await Get.find<PaymentController>().reload();
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final PaymentController controller = Get.find<PaymentController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 280,
          child: AppSearchField(
            hint: 'Search receipt or reference number',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 200,
          child: Obx(
            () => AppDropdown<PaymentMethod>(
              label: 'Method',
              hint: 'All',
              items: PaymentMethod.values,
              itemLabel: (PaymentMethod m) => m.label,
              value: controller.methodFilter.value,
              onChanged: controller.filterByMethod,
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: Obx(
            () => AppDropdown<PaymentStatus>(
              label: 'Status',
              hint: 'All',
              items: PaymentStatus.values,
              itemLabel: (PaymentStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: AppDateRangeField(
            label: 'Payment date',
            value: controller.params.value.dateRange,
            onChanged: controller.filterByDateRange,
          ),
        ),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.payment});

  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    if (!payment.canReverse) {
      return const SizedBox.shrink();
    }
    return AppPermissionView(
      permission: AppPermissions.paymentsRefund,
      child: AppIconButton(
        icon: Icons.undo,
        tooltip: 'Reverse',
        isDestructive: true,
        onPressed: () async {
          final String? reason = await AppDialog.confirmWithReason(
            title: 'Reverse this payment?',
            message:
                'A contra entry is written and the invoice balance is '
                'restored. The original receipt is kept, because the customer '
                'holds a copy of it.',
            confirmLabel: 'Reverse',
          );
          if (reason != null) {
            await Get.find<PaymentController>().reverse(
              payment: payment,
              reason: reason,
            );
          }
        },
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final PaymentModel payment;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                payment.paymentNumber,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: payment.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${payment.customerName ?? "-"} - ${payment.formattedDate}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              payment.formattedAmount,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            Text(
              payment.paymentMethod.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            _RowActions(payment: payment),
          ],
        ),
      ],
    ),
  );
}
