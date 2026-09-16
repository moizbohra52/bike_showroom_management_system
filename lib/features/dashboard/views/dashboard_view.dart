import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Dashboard.
///
/// Currently the landing surface that confirms the identity and authorisation
/// chain resolved correctly end to end. The metric tiles and charts described
/// in the specification are fed by `dashboard_metrics()` and the reporting
/// views, which arrive with the database migrations.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find<SessionController>();
    final ThemeData theme = Theme.of(context);

    return AppShell(
      title: 'Dashboard',
      body: AppContentContainer(
        child: SingleChildScrollView(
          child: Obx(() {
            final String? showroomName = session.activeShowroom?.name;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Welcome, ${session.userName}',
                  style: theme.textTheme.headlineLarge,
                ),
                AppSpacing.gapXs,
                Text(
                  <String>[
                    ?session.user?.roleLabel,
                    ?showroomName,
                    DateUtil.format(DateTime.now()),
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall,
                ),
                AppSpacing.gapXxl,

                // A verification panel rather than placeholder tiles: it shows
                // that the auth -> role -> permission -> showroom chain
                // resolved, which is the part worth confirming at this stage.
                Card(
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: AppColors.success,
                            ),
                            AppSpacing.hGapSm,
                            Text(
                              'Access resolved',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                        AppSpacing.gapLg,
                        _InfoRow(
                          label: 'Roles',
                          value: session.user?.roleLabel ?? '-',
                        ),
                        _InfoRow(
                          label: 'Permissions',
                          value: session.isSuperAdmin
                              ? 'All (super admin)'
                              : '${session.permissions.length} granted',
                        ),
                        _InfoRow(
                          label: 'Showrooms',
                          value: session.showrooms.isEmpty
                              ? 'None'
                              : session.showrooms
                                    .map((ShowroomModel s) => s.name)
                                    .join(', '),
                        ),
                        _InfoRow(
                          label: 'Active showroom',
                          value: showroomName ?? 'Not selected',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
