import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/auth/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Sets a new password using the recovery session from an email link.
///
/// Reached by deep link, which is why it is exempted from
/// [GuestOnlyMiddleware]: the recovery token establishes a limited session, so
/// the user is technically signed in when they arrive here.
class ResetPasswordView extends GetView<AuthController> {
  const ResetPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Set a new password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.password_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                AppSpacing.gapLg,
                Text(
                  'Choose a new password',
                  style: theme.textTheme.headlineMedium,
                ),
                AppSpacing.gapSm,
                Text(
                  'Use at least 8 characters with upper and lower case '
                  'letters and a number.',
                  style: theme.textTheme.bodySmall,
                ),
                AppSpacing.gapXl,
                Form(
                  key: controller.resetFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Obx(
                        () => AppPasswordField(
                          label: 'New password',
                          controller: controller.newPasswordController,
                          validator: controller.validateNewPassword,
                          isEnabled: !controller.isSubmitting.value,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          autofillHints: const <String>[
                            AutofillHints.newPassword,
                          ],
                        ),
                      ),
                      AppSpacing.gapLg,
                      Obx(
                        () => AppPasswordField(
                          label: 'Confirm new password',
                          controller: controller.confirmPasswordController,
                          validator: controller.validateConfirmPassword,
                          isEnabled: !controller.isSubmitting.value,
                          autofillHints: const <String>[
                            AutofillHints.newPassword,
                          ],
                          onSubmitted: (_) =>
                              controller.completePasswordReset(),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapXl,
                Obx(
                  () => AppButton.primary(
                    label: 'Update password',
                    size: AppButtonSize.large,
                    expand: true,
                    isLoading: controller.isSubmitting.value,
                    onPressed: controller.completePasswordReset,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
