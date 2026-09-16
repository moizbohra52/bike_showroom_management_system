import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shown for an unrecognised route.
///
/// Matters most on web, where a stale bookmark or a mistyped path is routine.
/// It offers a way back rather than leaving the user on a dead page.
class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isSignedIn =
        Get.isRegistered<SessionController>() &&
        Get.find<SessionController>().isSignedIn;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.explore_off_outlined,
                  size: 40,
                  color: theme.textTheme.bodySmall?.color,
                ),
                AppSpacing.gapLg,
                Text('Page not found', style: theme.textTheme.headlineMedium),
                AppSpacing.gapSm,
                Text(
                  'The page you were looking for does not exist, or you no '
                  'longer have access to it.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXl,
                AppButton.primary(
                  label: isSignedIn ? 'Go to dashboard' : 'Go to sign in',
                  onPressed: () => Get.offAllNamed(
                    isSignedIn ? AppRoutes.dashboard : AppRoutes.login,
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
