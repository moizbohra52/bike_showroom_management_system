import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/features/roles/controllers/role_controller.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Role list: the 13 seeded system roles plus any custom roles an
/// administrator has created.
class RoleListView extends GetView<RoleController> {
  const RoleListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Roles & Permissions',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.rolesManage,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Role',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => Get.toNamed(AppRoutes.roleForm),
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
              width: 320,
              child: AppSearchField(
                hint: 'Search roles',
                onChanged: controller.search,
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<RoleModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<RoleModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: (RoleModel role) => Get.toNamed(
                          AppRoutes.rolePermissions,
                          arguments: role,
                        ),
                        mobileCardBuilder:
                            (BuildContext context, RoleModel role) =>
                                _RoleCard(role: role),
                        columns: <AppDataColumn<RoleModel>>[
                          AppDataColumn<RoleModel>(
                            label: 'Name',
                            sortKey: 'name',
                            cellBuilder: (_, RoleModel r) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(r.label),
                                if (r.isSystemRole) ...<Widget>[
                                  AppSpacing.hGapSm,
                                  const Icon(
                                    Icons.verified_outlined,
                                    size: 14,
                                    color: AppColors.info,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          AppDataColumn<RoleModel>(
                            label: 'Description',
                            cellBuilder: (_, RoleModel r) =>
                                Text(r.description ?? '-'),
                          ),
                          AppDataColumn<RoleModel>(
                            label: 'Permissions',
                            numeric: true,
                            cellBuilder: (_, RoleModel r) => Text(
                              r.isSuperAdmin
                                  ? 'All'
                                  : '${r.permissions.length}',
                            ),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, RoleModel role) =>
                                _RowActions(role: role),
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

class _RowActions extends StatelessWidget {
  const _RowActions({required this.role});

  final RoleModel role;

  @override
  Widget build(BuildContext context) {
    final RoleController controller = Get.find<RoleController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPermissionView(
          permission: AppPermissions.rolesManage,
          child: AppIconButton(
            icon: Icons.security_outlined,
            tooltip: 'Edit permissions',
            onPressed: () =>
                Get.toNamed(AppRoutes.rolePermissions, arguments: role),
          ),
        ),
        if (!role.isSystemRole)
          AppPermissionView(
            permission: AppPermissions.rolesManage,
            child: AppIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Rename',
              onPressed: () => Get.toNamed(AppRoutes.roleForm, arguments: role),
            ),
          ),
        if (!role.isSystemRole)
          AppPermissionView(
            permission: AppPermissions.rolesManage,
            child: AppIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Delete',
              isDestructive: true,
              onPressed: () => controller.deleteRole(role),
            ),
          ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});

  final RoleModel role;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(role.label, style: Theme.of(context).textTheme.titleMedium),
              AppSpacing.gapXs,
              Text(
                role.isSuperAdmin
                    ? 'All permissions'
                    : '${role.permissions.length} permissions',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _RowActions(role: role),
      ],
    ),
  );
}
