import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/vehicles/controllers/vehicle_controller.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Customer-owned vehicles: branch-wide, or one customer's garage.
class VehicleListView extends GetView<VehicleController> {
  const VehicleListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: controller.title,
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.vehiclesCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Vehicle',
            icon: Icons.add,
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
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: SizedBox(
              width: 360,
              child: AppSearchField(
                hint: 'Search registration, chassis or engine number',
                onChanged: controller.search,
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<CustomerVehicleModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No vehicles recorded',
                        message:
                            'Vehicles appear here once they are delivered, '
                            'or when one is brought in for service.',
                        icon: Icons.two_wheeler_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<CustomerVehicleModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: _openForm,
                        mobileCardBuilder:
                            (BuildContext context, CustomerVehicleModel v) =>
                                _VehicleCard(vehicle: v),
                        columns: <AppDataColumn<CustomerVehicleModel>>[
                          AppDataColumn<CustomerVehicleModel>(
                            label: 'Registration',
                            sortKey: 'registration_number',
                            cellBuilder: (_, CustomerVehicleModel v) =>
                                Text(v.displayIdentifier),
                          ),
                          AppDataColumn<CustomerVehicleModel>(
                            label: 'Vehicle',
                            cellBuilder: (_, CustomerVehicleModel v) =>
                                Text(v.displayName),
                          ),
                          AppDataColumn<CustomerVehicleModel>(
                            label: 'Owner',
                            cellBuilder: (_, CustomerVehicleModel v) =>
                                Text(v.customerName ?? '-'),
                          ),
                          AppDataColumn<CustomerVehicleModel>(
                            label: 'Odometer',
                            sortKey: 'current_odometer',
                            numeric: true,
                            cellBuilder: (_, CustomerVehicleModel v) =>
                                Text('${v.currentOdometer} km'),
                          ),
                          AppDataColumn<CustomerVehicleModel>(
                            label: 'Insurance',
                            sortKey: 'insurance_end',
                            cellBuilder:
                                (
                                  BuildContext context,
                                  CustomerVehicleModel v,
                                ) => _ExpiryText(
                                  date: v.insuranceEnd,
                                  isExpiringSoon: v.isInsuranceExpiringSoon,
                                  isActive: v.isInsuranceActive,
                                ),
                          ),
                          AppDataColumn<CustomerVehicleModel>(
                            label: 'Status',
                            cellBuilder: (_, CustomerVehicleModel v) =>
                                AppStatusChip(status: v.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, CustomerVehicleModel v) =>
                                _RowActions(vehicle: v),
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
            permission: AppPermissions.vehiclesCreate,
            child: FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );

  /// Carries the customer through when the screen was opened from one, so the
  /// owner is pre-selected rather than hunted for in a list of thousands.
  static Future<void> _openForm([CustomerVehicleModel? vehicle]) async {
    final VehicleController controller = Get.find<VehicleController>();
    final Object? result = await Get.toNamed(
      AppRoutes.vehicleForm,
      arguments: vehicle ?? controller.customer,
    );
    if (result is CustomerVehicleModel) {
      await controller.reload();
    }
  }
}

/// An expiry date, coloured by how close it is. A lapsed policy is the thing
/// the showroom most needs to see at a glance.
class _ExpiryText extends StatelessWidget {
  const _ExpiryText({
    required this.date,
    required this.isExpiringSoon,
    required this.isActive,
  });

  final DateTime? date;
  final bool isExpiringSoon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const Text('-');
    }
    final Color? color = !isActive
        ? AppColors.danger
        : isExpiringSoon
        ? AppColors.warning
        : null;
    return Text(
      DateUtil.format(date),
      style: TextStyle(
        color: color,
        fontWeight: color == null ? null : FontWeight.w600,
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.vehicle});

  final CustomerVehicleModel vehicle;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      AppPermissionView(
        permission: AppPermissions.vehiclesEdit,
        child: AppIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          onPressed: () => VehicleListView._openForm(vehicle),
        ),
      ),
    ],
  );
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final CustomerVehicleModel vehicle;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => VehicleListView._openForm(vehicle),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                vehicle.displayIdentifier,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: vehicle.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${vehicle.displayName} - ${vehicle.customerName ?? "Unknown owner"}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              '${vehicle.currentOdometer} km',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            _ExpiryText(
              date: vehicle.insuranceEnd,
              isExpiringSoon: vehicle.isInsuranceExpiringSoon,
              isActive: vehicle.isInsuranceActive,
            ),
          ],
        ),
      ],
    ),
  );
}
