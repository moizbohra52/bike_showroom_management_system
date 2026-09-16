import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/features/auth/controllers/splash_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Boot screen. Owns the decision about where the user lands.
///
/// Kept as a real screen rather than a redirect because the bootstrap has
/// genuine asynchronous work to do — restoring a session, resolving the auth
/// context, priming the offline store — and any of it can fail in a way the
/// user needs to see.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Obx(
              () => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.two_wheeler_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  AppSpacing.gapLg,
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXxl,

                  if (controller.fatalError.value != null)
                    _FatalError(message: controller.fatalError.value!)
                  else ...<Widget>[
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    AppSpacing.gapLg,
                    Text(
                      controller.statusMessage.value,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A startup failure the user cannot work around by waiting.
///
/// Shown rather than swallowed because the usual cause is a misconfigured
/// build — a missing `SUPABASE_URL`, for instance — and silently hanging on a
/// spinner would make that impossible to diagnose in the field.
class _FatalError extends StatelessWidget {
  const _FatalError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        const Icon(Icons.error_outline, size: 36, color: AppColors.danger),
        AppSpacing.gapLg,
        Text(
          'The application could not start',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapSm,
        Text(
          message,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXl,
        AppButton.secondary(
          label: 'Try again',
          icon: Icons.refresh,
          onPressed: Get.find<SplashController>().bootstrap,
          size: AppButtonSize.small,
        ),
      ],
    );
  }
}
