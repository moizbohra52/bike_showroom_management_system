import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:flutter/material.dart';

/// A small coloured pill for any `status`-shaped column, using the shared
/// [AppColors.forStatus] mapping so a badge means the same thing — same
/// colour for "ACTIVE", same colour for "OVERDUE" — on every screen in the
/// application, from the showroom list to a service job card.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = AppColors.forStatus(status, isDark: isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.statusSurface(status, isDark: isDark),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}
