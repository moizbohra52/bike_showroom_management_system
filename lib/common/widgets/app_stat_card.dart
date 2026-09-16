import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:flutter/material.dart';

/// A single dashboard metric tile: an icon, a label, a value, and an optional
/// trend indicator.
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
    this.trend,
    this.isPositiveTrendGood = true,
    this.onTap,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;

  /// A signed percentage, e.g. `12.5` or `-4.0`. Null hides the trend row.
  final double? trend;

  /// Whether a positive [trend] should be shown as good (green) or bad (red).
  /// An expense trend, for instance, is bad when it rises.
  final bool isPositiveTrendGood;

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = accentColor ?? theme.colorScheme.primary;

    final bool? trendIsGood = trend == null
        ? null
        : (trend! >= 0) == isPositiveTrendGood;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Icon(icon, size: 18, color: accent),
                    ),
                    AppSpacing.hGapSm,
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMd,
              if (isLoading)
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(value, style: AppTypography.moneyLarge),
              if (trend != null && !isLoading) ...<Widget>[
                AppSpacing.gapXs,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      trend! >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 13,
                      color: trendIsGood!
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${trend!.abs().toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: trendIsGood
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
