import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/environment_config.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/features/auth/controllers/auth_controller.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Sign-in screen.
///
/// A single centred card on every platform. On desktop it sits on a tinted
/// backdrop with the product mark alongside; on mobile it fills the width.
class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppResponsiveLayout(
      mobile: (BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: _LoginCard(controller: controller),
        ),
      ),
      desktop: (BuildContext context) => Row(
        children: <Widget>[
          const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.huge),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _LoginCard(controller: controller),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Decorative panel shown beside the form on wide screens.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.two_wheeler_outlined,
              size: 56,
              color: theme.colorScheme.onPrimary,
            ),
            AppSpacing.gapXl,
            Text(
              AppConstants.appName,
              style: AppTypography.displayMedium.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
            AppSpacing.gapMd,
            Text(
              'Sales, service, finance and accounting for every showroom '
              'in one place.',
              style: AppTypography.bodyLarge.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.88),
              ),
            ),
            AppSpacing.gapXxl,
            _FeatureLine(
              icon: Icons.inventory_2_outlined,
              label: 'Live stock across showrooms',
            ),
            _FeatureLine(
              icon: Icons.receipt_long_outlined,
              label: 'GST invoicing and EMI schedules',
            ),
            _FeatureLine(
              icon: Icons.build_outlined,
              label: 'Job cards and free-service tracking',
            ),
            _FeatureLine(
              icon: Icons.cloud_off_outlined,
              label: 'Keeps working when the connection drops',
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(
      context,
    ).colorScheme.onPrimary.withValues(alpha: 0.92);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (EnvironmentConfig.showEnvironmentBadge)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: AppRadius.smAll,
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                EnvironmentConfig.environment.shortLabel,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ),
          ),

        // Compact screens have no brand panel, so the mark goes here.
        if (context.isCompact) ...<Widget>[
          Icon(
            Icons.two_wheeler_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          AppSpacing.gapLg,
        ],

        Text('Sign in', style: theme.textTheme.headlineLarge),
        AppSpacing.gapXs,
        Text(
          'Use the credentials issued by your administrator.',
          style: theme.textTheme.bodySmall,
        ),
        AppSpacing.gapXl,

        // A non-field error — a rejected credential or an unprovisioned
        // account — shown inline so it stays readable while retyping.
        Obx(() {
          final String? error = controller.formError.value;
          if (error == null) {
            return const SizedBox.shrink();
          }
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dangerSurface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: Text(
                    error,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        Form(
          key: controller.loginFormKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Obx(
                  () => AppTextField.email(
                    controller: controller.emailController,
                    validator: controller.validateEmail,
                    errorText: controller.fieldErrors['email'],
                    isEnabled: !controller.isSubmitting.value,
                    autofocus: true,
                  ),
                ),
                AppSpacing.gapLg,
                Obx(
                  () => AppPasswordField(
                    controller: controller.passwordController,
                    validator: controller.validateSignInPassword,
                    errorText: controller.fieldErrors['password'],
                    isEnabled: !controller.isSubmitting.value,
                    // Enter submits, which is what a keyboard-driven desktop
                    // user expects.
                    onSubmitted: (_) => controller.signIn(),
                  ),
                ),
                AppSpacing.gapMd,
                Row(
                  children: <Widget>[
                    Obx(
                      () => Checkbox(
                        value: controller.rememberEmail.value,
                        onChanged: (bool? value) =>
                            controller.rememberEmail.value = value ?? false,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Text('Remember my email', style: theme.textTheme.bodySmall),
                    const Spacer(),
                    AppButton.ghost(
                      label: 'Forgot password?',
                      size: AppButtonSize.small,
                      onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                    ),
                  ],
                ),
                AppSpacing.gapXl,
                Obx(
                  () => AppButton.primary(
                    label: 'Sign in',
                    size: AppButtonSize.large,
                    expand: true,
                    isLoading: controller.isSubmitting.value,
                    onPressed: controller.signIn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
