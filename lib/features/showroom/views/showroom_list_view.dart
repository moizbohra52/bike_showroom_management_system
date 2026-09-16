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
import 'package:bike_showroom_management_system/features/showroom/controllers/showroom_controller.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Showroom list: every branch a super admin sees, or every branch a manager
/// has been assigned to. Row Level Security decides which; this screen shows
/// whatever comes back.
class ShowroomListView extends GetView<ShowroomController> {
  const ShowroomListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Showrooms',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.showroomCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Showroom',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => Get.toNamed(AppRoutes.showroomForm),
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
                hint: 'Search by name, code or city',
                onChanged: controller.search,
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<ShowroomModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No showrooms yet',
                        message: 'Add your first showroom to get started.',
                        icon: Icons.storefront_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<ShowroomModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: (ShowroomModel showroom) => Get.toNamed(
                          AppRoutes.showroomForm,
                          arguments: showroom,
                        ),
                        mobileCardBuilder:
                            (BuildContext context, ShowroomModel s) =>
                                _ShowroomCard(showroom: s),
                        columns: <AppDataColumn<ShowroomModel>>[
                          AppDataColumn<ShowroomModel>(
                            label: 'Code',
                            sortKey: 'code',
                            cellBuilder: (_, ShowroomModel s) => Text(s.code),
                          ),
                          AppDataColumn<ShowroomModel>(
                            label: 'Name',
                            sortKey: 'name',
                            cellBuilder: (_, ShowroomModel s) => Text(s.name),
                          ),
                          AppDataColumn<ShowroomModel>(
                            label: 'City',
                            cellBuilder: (_, ShowroomModel s) =>
                                Text(s.city ?? '-'),
                          ),
                          AppDataColumn<ShowroomModel>(
                            label: 'Phone',
                            cellBuilder: (_, ShowroomModel s) =>
                                Text(s.phone ?? '-'),
                          ),
                          AppDataColumn<ShowroomModel>(
                            label: 'Status',
                            cellBuilder: (_, ShowroomModel s) =>
                                AppStatusChip(status: s.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, ShowroomModel s) =>
                                _RowActions(showroom: s),
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
            permission: AppPermissions.showroomCreate,
            child: FloatingActionButton(
              onPressed: () => Get.toNamed(AppRoutes.showroomForm),
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.showroom});

  final ShowroomModel showroom;

  @override
  Widget build(BuildContext context) {
    final ShowroomController controller = Get.find<ShowroomController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPermissionView(
          permission: AppPermissions.showroomEdit,
          child: AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () =>
                Get.toNamed(AppRoutes.showroomForm, arguments: showroom),
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.showroomEdit,
          child: AppIconButton(
            icon: showroom.isActive
                ? Icons.toggle_on
                : Icons.toggle_off_outlined,
            tooltip: showroom.isActive ? 'Deactivate' : 'Activate',
            onPressed: () => controller.toggleStatus(showroom),
          ),
        ),
      ],
    );
  }
}

class _ShowroomCard extends StatelessWidget {
  const _ShowroomCard({required this.showroom});

  final ShowroomModel showroom;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      showroom.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  AppStatusChip(status: showroom.status.value),
                ],
              ),
              AppSpacing.gapXs,
              Text(
                '${showroom.code} - ${showroom.city ?? "No city set"}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _RowActions(showroom: showroom),
      ],
    ),
  );
}
