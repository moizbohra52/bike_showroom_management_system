import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:flutter/material.dart';

/// The application's card surface.
///
/// A thin wrapper over [Card] rather than using it directly everywhere, so
/// padding, an optional header row and an optional tap target are consistent
/// across every screen that groups content into a panel.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.margin,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title!, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            AppSpacing.gapLg,
          ],
          child,
        ],
      ),
    );

    final Widget card = Card(
      margin: margin ?? EdgeInsets.zero,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: AppRadius.lgAll,
              child: content,
            ),
    );

    return card;
  }
}
