import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:flutter/material.dart';

/// Lays out form fields evenly across a row on desktop, and stacked one per
/// row on mobile.
///
/// Nearly every form in the application — showroom, product, customer, sale,
/// service — groups two or three related fields on one line on a wide
/// screen and stacks them on a phone. Defined once here rather than as a
/// private widget per form, so the spacing and the breakpoint behaviour are
/// identical everywhere.
class AppFieldRow extends StatelessWidget {
  const AppFieldRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppResponsiveLayout(
    mobile: (BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) AppSpacing.gapLg,
          children[i],
        ],
      ],
    ),
    desktop: (BuildContext context) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) AppSpacing.hGapLg,
          Expanded(child: children[i]),
        ],
      ],
    ),
  );
}
