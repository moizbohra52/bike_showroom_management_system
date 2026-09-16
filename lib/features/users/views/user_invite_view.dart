import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:bike_showroom_management_system/features/users/controllers/user_invite_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Invites a new person: creates their Supabase Auth account through the
/// `invite-user` Edge Function (see [UserInviteController]'s documentation
/// for why a client can never do this directly) and assigns their first
/// role and showroom in the same step.
class UserInviteView extends GetView<UserInviteController> {
  const UserInviteView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invite User')),
    body: Obx(() {
      if (controller.isLoading.value) {
        return const AppLoader(message: 'Loading roles and showrooms...');
      }
      return Center(
        child: SingleChildScrollView(
          padding: context.pagePadding,
          child: AppContentContainer(
            maxWidth: 560,
            padding: EdgeInsets.zero,
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'The new user will receive an email to set their '
                    'password and sign in.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  AppSpacing.gapXl,
                  AppTextField(
                    label: 'Full name',
                    controller: controller.nameController,
                    validator: controller.validateName,
                    isRequired: true,
                    autofocus: true,
                  ),
                  AppSpacing.gapLg,
                  AppTextField.email(
                    controller: controller.emailController,
                    validator: controller.validateEmail,
                  ),
                  AppSpacing.gapLg,
                  AppFieldRow(
                    children: <Widget>[
                      AppTextField.phone(
                        label: 'Phone',
                        controller: controller.phoneController,
                        validator: controller.validatePhone,
                        isRequired: false,
                      ),
                      AppTextField.code(
                        label: 'Employee code',
                        controller: controller.employeeCodeController,
                        isRequired: false,
                        maxLength: 20,
                      ),
                    ],
                  ),
                  AppSpacing.gapLg,
                  Obx(
                    () => AppDropdown<ShowroomModel>(
                      label: 'Showroom',
                      isRequired: true,
                      items: controller.assignableShowrooms,
                      itemLabel: (ShowroomModel s) => '${s.name} (${s.code})',
                      value: controller.selectedShowroom.value,
                      onChanged: (ShowroomModel? value) =>
                          controller.selectedShowroom.value = value,
                    ),
                  ),
                  AppSpacing.gapLg,
                  Obx(
                    () => AppDropdown<RoleModel>(
                      label: 'Role',
                      isRequired: true,
                      items: controller.assignableRoles,
                      itemLabel: (RoleModel r) => r.label,
                      value: controller.selectedRole.value,
                      onChanged: (RoleModel? value) =>
                          controller.selectedRole.value = value,
                    ),
                  ),
                  AppSpacing.gapXxl,
                  Row(
                    children: <Widget>[
                      AppButton.ghost(label: 'Cancel', onPressed: Get.back),
                      const Spacer(),
                      Obx(
                        () => AppButton.primary(
                          label: 'Send invite',
                          isLoading: controller.isSubmitting.value,
                          onPressed: () async {
                            final bool sent = await controller.submit();
                            if (sent) {
                              Get.back(result: true);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }),
  );
}
