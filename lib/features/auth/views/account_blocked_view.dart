import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/auth/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shown when the credential is valid but the account cannot use the app.
///
/// There are three realistic causes and the user can act on none of them, so
/// the screen exists to explain rather than to offer a remedy: the profile has
/// no role, it has no showroom assignment, or it has been deactivated.
///
/// The Supabase auth trigger creates a profile row the moment an account is
/// created, so a half-finished onboarding produces exactly this state. Landing
/// such a user on an empty dashboard full of failing queries would be far
/// worse than telling them plainly.
class AccountBlockedView extends StatelessWidget {
  const AccountBlockedView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = Get.find<SessionController>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Obx(
              () => Column(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.manage_accounts_outlined,
                      size: 32,
                      color: AppColors.warning,
                    ),
                  ),
                  AppSpacing.gapXl,
                  Text(
                    'Your account needs attention',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapMd,
                  Text(
                    session.provisioningIssue.value ??
                        'Your account is not yet set up for this '
                            'application. Please contact your administrator.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (session.userName.isNotEmpty) ...<Widget>[
                    AppSpacing.gapXl,
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _DetailRow(
                            label: 'Signed in as',
                            value: session.userName,
                          ),
                          if (session.user?.email != null)
                            _DetailRow(
                              label: 'Email',
                              value: session.user!.email!,
                            ),
                          _DetailRow(
                            label: 'Roles',
                            value: session.user?.roles.isEmpty ?? true
                                ? 'None assigned'
                                : session.user!.roleLabel,
                          ),
                          _DetailRow(
                            label: 'Showrooms',
                            value: session.showrooms.isEmpty
                                ? 'None assigned'
                                : '${session.showrooms.length} assigned',
                          ),
                        ],
                      ),
                    ),
                  ],
                  AppSpacing.gapXl,
                  // Re-checking is genuinely useful here: an administrator may
                  // complete the assignment while the user waits.
                  AppButton.secondary(
                    label: 'Check again',
                    icon: Icons.refresh,
                    expand: true,
                    onPressed: session.refreshContext,
                  ),
                  AppSpacing.gapSm,
                  AppButton.ghost(
                    label: 'Sign out',
                    expand: true,
                    onPressed: () => Get.find<AuthController>().signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
