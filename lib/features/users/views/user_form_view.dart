import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/auth/models/app_user_model.dart';
import 'package:bike_showroom_management_system/features/users/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Edits a user's profile fields. Email, status and role/showroom
/// assignment are deliberately not here — see [UserFormController]'s
/// documentation for why each of those has its own dedicated flow.
class UserFormView extends GetView<UserFormController> {
  const UserFormView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Edit ${controller.user.name}')),
    body: Center(
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
                // Read-only reminder of the sign-in email: shown for
                // context, but not an editable field here.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.mail_outline, size: 16),
                      AppSpacing.hGapSm,
                      Text(
                        controller.user.email ?? 'No email on file',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapLg,
                AppTextField(
                  label: 'Name',
                  controller: controller.nameController,
                  validator: controller.validateName,
                  isRequired: true,
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
                AppTextField(
                  label: 'Designation',
                  controller: controller.designationController,
                  hint: 'e.g. Senior Sales Executive',
                ),
                AppSpacing.gapXxl,
                Row(
                  children: <Widget>[
                    AppButton.ghost(label: 'Cancel', onPressed: Get.back),
                    const Spacer(),
                    Obx(
                      () => AppButton.primary(
                        label: 'Save changes',
                        isLoading: controller.isSubmitting.value,
                        onPressed: () async {
                          final AppUserModel? saved = await controller.submit();
                          if (saved != null) {
                            Get.back(result: saved);
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
    ),
  );
}
