import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/auth/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Requests a password-reset email.
///
/// The confirmation is intentionally non-committal about whether the address
/// exists, so this screen cannot be used to discover which emails are
/// registered.
class ForgotPasswordView extends GetView<AuthController> {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset password'),
        leading: BackButton(onPressed: Get.back),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Obx(
              () => controller.resetEmailSent.value
                  ? _SentConfirmation(theme: theme)
                  : _RequestForm(controller: controller, theme: theme),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({required this.controller, required this.theme});

  final AuthController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Icon(
        Icons.lock_reset_outlined,
        size: 40,
        color: theme.colorScheme.primary,
      ),
      AppSpacing.gapLg,
      Text('Forgot your password?', style: theme.textTheme.headlineMedium),
      AppSpacing.gapSm,
      Text(
        'Enter the email address on your account and we will send you a '
        'link to set a new password.',
        style: theme.textTheme.bodySmall,
      ),
      AppSpacing.gapXl,
      Form(
        key: controller.forgotFormKey,
        child: Obx(
          () => AppTextField.email(
            controller: controller.forgotEmailController,
            validator: controller.validateEmail,
            isEnabled: !controller.isSubmitting.value,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => controller.sendPasswordReset(),
          ),
        ),
      ),
      AppSpacing.gapXl,
      Obx(
        () => AppButton.primary(
          label: 'Send reset link',
          size: AppButtonSize.large,
          expand: true,
          isLoading: controller.isSubmitting.value,
          onPressed: controller.sendPasswordReset,
        ),
      ),
      AppSpacing.gapMd,
      AppButton.ghost(label: 'Back to sign in', onPressed: Get.back),
    ],
  );
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Icon(
        Icons.mark_email_read_outlined,
        size: 40,
        color: AppColors.success,
      ),
      AppSpacing.gapLg,
      Text('Check your email', style: theme.textTheme.headlineMedium),
      AppSpacing.gapSm,
      Text(
        'If that address is registered with us, a reset link is on its '
        'way. The link expires in one hour.',
        style: theme.textTheme.bodySmall,
      ),
      AppSpacing.gapSm,
      Text(
        'Not seeing it? Check your spam folder, or ask your administrator '
        'to confirm the address on your account.',
        style: theme.textTheme.bodySmall,
      ),
      AppSpacing.gapXl,
      AppButton.secondary(
        label: 'Back to sign in',
        expand: true,
        onPressed: Get.back,
      ),
    ],
  );
}
