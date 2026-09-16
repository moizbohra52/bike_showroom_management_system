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
import 'package:bike_showroom_management_system/features/purchases/controllers/purchase_controller.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Purchase orders raised by the active showroom.
class PurchaseListView extends GetView<PurchaseController> {
  const PurchaseListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Purchases',
    actions: <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: AppButton.ghost(
          label: 'Suppliers',
          icon: Icons.local_shipping_outlined,
          size: AppButtonSize.small,
          onPressed: () => Get.toNamed(AppRoutes.suppliers),
        ),
      ),
      AppPermissionView(
        permission: AppPermissions.purchasesCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'New Purchase',
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
              () => AppAsyncBuilder<PurchaseModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No purchases yet',
                        message:
                            'Raise a purchase order, then receive it to take '
                            'the machines into stock.',
                        icon: Icons.shopping_cart_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<PurchaseModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: _openDetails,
                        mobileCardBuilder:
                            (BuildContext context, PurchaseModel p) =>
                                _PurchaseCard(purchase: p),
                        columns: <AppDataColumn<PurchaseModel>>[
                          AppDataColumn<PurchaseModel>(
                            label: 'Purchase',
                            sortKey: 'purchase_number',
                            cellBuilder: (_, PurchaseModel p) =>
                                Text(p.purchaseNumber),
                          ),
                          AppDataColumn<PurchaseModel>(
                            label: 'Date',
                            sortKey: 'purchase_date',
                            cellBuilder: (_, PurchaseModel p) =>
                                Text(p.formattedDate),
                          ),
                          AppDataColumn<PurchaseModel>(
                            label: 'Supplier',
                            cellBuilder: (_, PurchaseModel p) =>
                                Text(p.supplierName ?? '-'),
                          ),
                          AppDataColumn<PurchaseModel>(
                            label: 'Supplier invoice',
                            cellBuilder: (_, PurchaseModel p) =>
                                Text(p.supplierInvoiceNo ?? '-'),
                          ),
                          AppDataColumn<PurchaseModel>(
                            label: 'Total',
                            sortKey: 'total_amount',
                            numeric: true,
                            cellBuilder: (_, PurchaseModel p) =>
                                Text(p.formattedTotal),
                          ),
                          AppDataColumn<PurchaseModel>(
                            label: 'Outstanding',
                            sortKey: 'outstanding_amount',
                            numeric: true,
                            cellBuilder:
                                (BuildContext context, PurchaseModel p) => Text(
                                  p.formattedOutstanding,
                                  style: p.outstandingAmount > 0.01
                                      ? const TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                        )
                                      : null,
                                ),
                          ),
                          AppDataColumn<PurchaseModel>(
                            label: 'Status',
                            sortKey: 'status',
                            cellBuilder: (_, PurchaseModel p) =>
                                AppStatusChip(status: p.status.value),
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
            permission: AppPermissions.purchasesCreate,
            child: FloatingActionButton(
              onPressed: _openCreate,
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );

  static Future<void> _openCreate() async {
    final Object? result = await Get.toNamed(AppRoutes.purchaseCreate);
    if (result is String) {
      await Get.find<PurchaseController>().reload();
    }
  }

  static Future<void> _openDetails(PurchaseModel purchase) async {
    await Get.toNamed(AppRoutes.purchaseDetails, arguments: purchase);
    // Receiving a consignment changes the row's status.
    await Get.find<PurchaseController>().reload();
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final PurchaseController controller = Get.find<PurchaseController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 300,
          child: AppSearchField(
            hint: 'Search purchase or supplier invoice number',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 220,
          child: Obx(
            () => AppDropdown<PurchaseStatus>(
              label: 'Status',
              hint: 'All',
              items: PurchaseStatus.values,
              itemLabel: (PurchaseStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: AppDateRangeField(
            label: 'Purchase date',
            value: controller.params.value.dateRange,
            onChanged: controller.filterByDateRange,
          ),
        ),
        AppButton.ghost(
          label: 'Awaiting delivery',
          icon: Icons.local_shipping_outlined,
          size: AppButtonSize.small,
          onPressed: controller.showPendingReceipt,
        ),
      ],
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.purchase});

  final PurchaseModel purchase;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => PurchaseListView._openDetails(purchase),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                purchase.purchaseNumber,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: purchase.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${purchase.supplierName ?? "Unknown"} - ${purchase.formattedDate}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              purchase.formattedTotal,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            if (purchase.canReceive)
              Text(
                'Awaiting delivery',
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
