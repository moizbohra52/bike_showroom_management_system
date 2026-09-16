import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_avatar.dart';
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
import 'package:bike_showroom_management_system/features/auth/models/app_user_model.dart';
import 'package:bike_showroom_management_system/features/users/controllers/user_controller.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Staff list, across every showroom the caller may reach.
class UserListView extends GetView<UserController> {
  const UserListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Users',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.usersCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Invite User',
            icon: Icons.person_add_alt_outlined,
            size: AppButtonSize.small,
            onPressed: () => Get.toNamed(AppRoutes.userInvite),
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
                hint: 'Search by name, email, phone or code',
                onChanged: controller.search,
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<AppUserModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<AppUserModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: (AppUserModel user) =>
                            Get.toNamed(AppRoutes.userDetails, arguments: user),
                        mobileCardBuilder:
                            (BuildContext context, AppUserModel user) =>
                                _UserCard(user: user),
                        columns: <AppDataColumn<AppUserModel>>[
                          AppDataColumn<AppUserModel>(
                            label: 'Name',
                            sortKey: 'name',
                            cellBuilder: (_, AppUserModel u) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                AppAvatar(
                                  name: u.name,
                                  imageUrl: u.avatarUrl,
                                  size: 28,
                                ),
                                AppSpacing.hGapSm,
                                Text(u.name),
                              ],
                            ),
                          ),
                          AppDataColumn<AppUserModel>(
                            label: 'Role',
                            cellBuilder: (_, AppUserModel u) =>
                                Text(u.roleLabel),
                          ),
                          AppDataColumn<AppUserModel>(
                            label: 'Email',
                            cellBuilder: (_, AppUserModel u) =>
                                Text(u.email ?? '-'),
                          ),
                          AppDataColumn<AppUserModel>(
                            label: 'Phone',
                            cellBuilder: (_, AppUserModel u) =>
                                Text(u.phone ?? '-'),
                          ),
                          AppDataColumn<AppUserModel>(
                            label: 'Status',
                            cellBuilder: (_, AppUserModel u) =>
                                AppStatusChip(status: u.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, AppUserModel u) =>
                                _RowActions(user: u),
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
  const _RowActions({required this.user});

  final AppUserModel user;

  @override
  Widget build(BuildContext context) {
    final UserController controller = Get.find<UserController>();
    final bool isSelf = user.id == Get.find<SessionController>().userId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPermissionView(
          permission: AppPermissions.usersAssign,
          child: AppIconButton(
            icon: Icons.admin_panel_settings_outlined,
            tooltip: 'Assign roles & showrooms',
            onPressed: () => Get.toNamed(AppRoutes.userRoles, arguments: user),
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.usersEdit,
          child: AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit profile',
            onPressed: () => Get.toNamed(AppRoutes.userForm, arguments: user),
          ),
        ),
        if (!isSelf)
          AppPermissionView(
            permission: AppPermissions.usersDelete,
            child: AppIconButton(
              icon: user.isActive ? Icons.toggle_on : Icons.toggle_off_outlined,
              tooltip: user.isActive ? 'Deactivate' : 'Reactivate',
              onPressed: () => controller.toggleStatus(user),
            ),
          ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AppUserModel user;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        AppAvatar(name: user.name, imageUrl: user.avatarUrl, size: 40),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  AppStatusChip(status: user.status.value),
                ],
              ),
              AppSpacing.gapXs,
              Text(
                user.roleLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _RowActions(user: user),
      ],
    ),
  );
}
