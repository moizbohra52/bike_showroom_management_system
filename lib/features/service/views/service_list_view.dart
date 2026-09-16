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
import 'package:bike_showroom_management_system/features/service/controllers/service_controller.dart';
import 'package:bike_showroom_management_system/features/service/models/service_record_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Job cards at the active showroom — the workshop board.
class ServiceListView extends GetView<ServiceController> {
  const ServiceListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Service',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.serviceCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Book Service',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: _openBooking,
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
              () => AppAsyncBuilder<ServiceRecordModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No job cards yet',
                        message:
                            'Book a service against a customer vehicle. Parts '
                            'and labour are added as the work proceeds.',
                        icon: Icons.build_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<ServiceRecordModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: _openDetails,
                        mobileCardBuilder:
                            (BuildContext context, ServiceRecordModel s) =>
                                _ServiceCard(service: s),
                        columns: <AppDataColumn<ServiceRecordModel>>[
                          AppDataColumn<ServiceRecordModel>(
                            label: 'Job card',
                            sortKey: 'service_number',
                            cellBuilder: (_, ServiceRecordModel s) =>
                                Text(s.serviceNumber),
                          ),
                          AppDataColumn<ServiceRecordModel>(
                            label: 'Date',
                            sortKey: 'service_date',
                            cellBuilder: (_, ServiceRecordModel s) =>
                                Text(s.formattedDate),
                          ),
                          AppDataColumn<ServiceRecordModel>(
                            label: 'Vehicle',
                            cellBuilder: (_, ServiceRecordModel s) =>
                                Text(s.vehicleLabel),
                          ),
                          AppDataColumn<ServiceRecordModel>(
                            label: 'Customer',
                            cellBuilder: (_, ServiceRecordModel s) =>
                                Text(s.customerName ?? '-'),
                          ),
                          AppDataColumn<ServiceRecordModel>(
                            label: 'Type',
                            sortKey: 'service_type',
                            cellBuilder: (_, ServiceRecordModel s) =>
                                Text(s.serviceType.label),
                          ),
                          AppDataColumn<ServiceRecordModel>(
                            label: 'Total',
                            sortKey: 'total_amount',
                            numeric: true,
                            cellBuilder: (_, ServiceRecordModel s) =>
                                Text(s.formattedTotal),
                          ),
                          AppDataColumn<ServiceRecordModel>(
                            label: 'Status',
                            sortKey: 'service_status',
                            cellBuilder: (_, ServiceRecordModel s) =>
                                AppStatusChip(status: s.serviceStatus.value),
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
            permission: AppPermissions.serviceCreate,
            child: FloatingActionButton(
              onPressed: _openBooking,
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );

  static Future<void> _openBooking() async {
    final Object? result = await Get.toNamed(AppRoutes.serviceBooking);
    if (result is ServiceRecordModel) {
      await Get.find<ServiceController>().reload();
      // Straight into the job card: the advisor's next act is always to add
      // the complaint's parts and labour.
      await _openDetails(result);
    }
  }

  static Future<void> _openDetails(ServiceRecordModel service) async {
    await Get.toNamed(AppRoutes.serviceDetails, arguments: service);
    await Get.find<ServiceController>().reload();
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final ServiceController controller = Get.find<ServiceController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 280,
          child: AppSearchField(
            hint: 'Search job card or complaint',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 210,
          child: Obx(
            () => AppDropdown<ServiceStatus>(
              label: 'Status',
              hint: 'All',
              items: ServiceStatus.values,
              itemLabel: (ServiceStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: Obx(
            () => AppDropdown<ServiceType>(
              label: 'Type',
              hint: 'All',
              items: ServiceType.values,
              itemLabel: (ServiceType t) => t.label,
              value: controller.typeFilter.value,
              onChanged: controller.filterByType,
            ),
          ),
        ),
        SizedBox(
          width: 250,
          child: AppDateRangeField(
            label: 'Service date',
            value: controller.params.value.dateRange,
            onChanged: controller.filterByDateRange,
          ),
        ),
        AppButton.ghost(
          label: 'Open jobs',
          icon: Icons.build_circle_outlined,
          size: AppButtonSize.small,
          onPressed: controller.showOpenOnly,
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final ServiceRecordModel service;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => ServiceListView._openDetails(service),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                service.vehicleLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: service.serviceStatus.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${service.serviceNumber} - ${service.customerName ?? "Unknown"} - '
          '${service.formattedDate}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (service.complaint != null && service.complaint!.isNotEmpty) ...[
          AppSpacing.gapXs,
          Text(
            service.complaint!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              service.serviceType.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              service.formattedTotal,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ],
    ),
  );
}
