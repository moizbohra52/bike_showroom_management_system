import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
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
import 'package:bike_showroom_management_system/features/customers/controllers/customer_controller.dart';
import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Customers of the active showroom.
class CustomerListView extends GetView<CustomerController> {
  const CustomerListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Customers',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.customersCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Customer',
            icon: Icons.person_add_alt,
            size: AppButtonSize.small,
            onPressed: () => _openForm(),
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
              () => AppAsyncBuilder<CustomerModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No customers yet',
                        message:
                            'Add a customer to start recording sales and '
                            'service.',
                        icon: Icons.people_outline,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<CustomerModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: _openForm,
                        mobileCardBuilder:
                            (BuildContext context, CustomerModel c) =>
                                _CustomerCard(customer: c),
                        columns: <AppDataColumn<CustomerModel>>[
                          AppDataColumn<CustomerModel>(
                            label: 'Code',
                            sortKey: 'customer_code',
                            cellBuilder: (_, CustomerModel c) =>
                                Text(c.customerCode),
                          ),
                          AppDataColumn<CustomerModel>(
                            label: 'Name',
                            sortKey: 'name',
                            cellBuilder: (_, CustomerModel c) => Text(c.name),
                          ),
                          AppDataColumn<CustomerModel>(
                            label: 'Phone',
                            sortKey: 'phone',
                            cellBuilder: (_, CustomerModel c) => Text(c.phone),
                          ),
                          AppDataColumn<CustomerModel>(
                            label: 'City',
                            cellBuilder: (_, CustomerModel c) =>
                                Text(c.city ?? '-'),
                          ),
                          AppDataColumn<CustomerModel>(
                            label: 'Type',
                            sortKey: 'customer_type',
                            cellBuilder: (_, CustomerModel c) =>
                                Text(c.customerType.label),
                          ),
                          AppDataColumn<CustomerModel>(
                            label: 'Vehicles',
                            numeric: true,
                            cellBuilder: (_, CustomerModel c) =>
                                Text('${c.vehicleCount}'),
                          ),
                          AppDataColumn<CustomerModel>(
                            label: 'Status',
                            cellBuilder: (_, CustomerModel c) =>
                                AppStatusChip(status: c.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, CustomerModel c) =>
                                _RowActions(customer: c),
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
            permission: AppPermissions.customersCreate,
            child: FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.person_add_alt),
            ),
          )
        : null,
  );

  static Future<void> _openForm([CustomerModel? customer]) async {
    final Object? result = await Get.toNamed(
      AppRoutes.customerForm,
      arguments: customer,
    );
    if (result is CustomerModel) {
      await Get.find<CustomerController>().reload();
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final CustomerController controller = Get.find<CustomerController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 320,
          child: AppSearchField(
            hint: 'Search by name, phone, code or email',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 220,
          child: Obx(
            () => AppDropdown<CustomerType>(
              label: 'Type',
              hint: 'All types',
              items: CustomerType.values,
              itemLabel: (CustomerType t) => t.label,
              value: controller.typeFilter.value,
              onChanged: controller.filterByType,
            ),
          ),
        ),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.customer});

  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    final CustomerController controller = Get.find<CustomerController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPermissionView(
          permission: AppPermissions.vehiclesView,
          child: AppIconButton(
            icon: Icons.two_wheeler_outlined,
            tooltip: 'Vehicles',
            onPressed: () =>
                Get.toNamed(AppRoutes.customerVehicles, arguments: customer),
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.customersEdit,
          child: AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () => CustomerListView._openForm(customer),
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.customersEdit,
          child: AppIconButton(
            icon: customer.isActive
                ? Icons.toggle_on
                : Icons.toggle_off_outlined,
            tooltip: customer.isActive ? 'Deactivate' : 'Activate',
            onPressed: () => controller.toggleStatus(customer),
          ),
        ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final CustomerModel customer;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => CustomerListView._openForm(customer),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                customer.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: customer.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${customer.customerCode} - ${customer.phone}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              customer.customerType.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              '${customer.vehicleCount} vehicle(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    ),
  );
}
