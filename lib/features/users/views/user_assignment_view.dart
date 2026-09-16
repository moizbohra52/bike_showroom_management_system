import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:bike_showroom_management_system/features/users/controllers/user_assignment_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The "controlled onboarding" screen the specification requires (§83):
/// grants and revokes roles and showrooms for one user, applying each change
/// immediately rather than behind a single Save button — every toggle here
/// is independently meaningful and independently re-authorised by RLS, so
/// there is nothing a batched save would protect that immediate feedback
/// does not already give the administrator.
class UserAssignmentView extends GetView<UserAssignmentController> {
  const UserAssignmentView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Obx(() => Text('Access - ${controller.user.name}'))),
    body: Obx(() {
      if (controller.isLoading.value) {
        return const AppLoader(message: 'Loading roles and showrooms...');
      }
      return SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppCard(
                title: 'Roles',
                subtitle: 'What this person is allowed to do',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final RoleModel role in controller.allRoles)
                      _RoleRow(role: role),
                  ],
                ),
              ),
              AppSpacing.gapLg,
              AppCard(
                title: 'Showrooms',
                subtitle: 'Which branches this person may access',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final ShowroomModel showroom
                        in controller.allShowrooms)
                      _ShowroomRow(showroom: showroom),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }),
  );
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role});

  final RoleModel role;

  @override
  Widget build(BuildContext context) {
    final UserAssignmentController controller =
        Get.find<UserAssignmentController>();

    return Obx(() {
      final bool held = controller.heldRoleIds.contains(role.id);
      final bool pending = controller.pendingIds.contains(role.id);

      return ListTile(
        title: Text(role.label),
        subtitle: role.description == null ? null : Text(role.description!),
        trailing: pending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                value: held,
                onChanged: (bool value) =>
                    controller.toggleRole(role, grant: value),
              ),
      );
    });
  }
}

class _ShowroomRow extends StatelessWidget {
  const _ShowroomRow({required this.showroom});

  final ShowroomModel showroom;

  @override
  Widget build(BuildContext context) {
    final UserAssignmentController controller =
        Get.find<UserAssignmentController>();

    return Obx(() {
      final bool held = controller.heldShowroomIds.contains(showroom.id);
      final bool isHome = showroom.id == controller.user.showroomId;
      final bool pending = controller.pendingIds.contains(showroom.id);

      return ListTile(
        title: Text(showroom.name),
        subtitle: Text(
          isHome ? '${showroom.code} - Home showroom' : showroom.code,
        ),
        trailing: pending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                value: held,
                onChanged: isHome
                    ? null
                    : (bool value) =>
                          controller.toggleShowroom(showroom, grant: value),
              ),
      );
    });
  }
}
