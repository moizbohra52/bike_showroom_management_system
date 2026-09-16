import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:flutter/widgets.dart';

/// Resolves the current [ScreenSize] and exposes it to the widget tree.
///
/// Breakpoints are read from the layout constraints rather than from
/// `MediaQuery.size`, because on desktop and web the application can sit in a
/// split pane or a resized window that is far narrower than the display. A
/// desktop table crammed into a 500px pane needs the mobile treatment.
extension ScreenSizeContext on BuildContext {
  /// Current breakpoint class, derived from the window width.
  ScreenSize get screenSize {
    final double width = MediaQuery.sizeOf(this).width;
    return ScreenSizeResolver.fromWidth(width);
  }

  bool get isMobile => screenSize.isMobile;
  bool get isTablet => screenSize.isTablet;
  bool get isDesktop => screenSize.isDesktopClass;
  bool get isCompact => screenSize.isCompact;

  /// Page padding appropriate to the breakpoint.
  EdgeInsets get pagePadding => screenSize.isCompact
      ? const EdgeInsets.all(16)
      : const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
}

/// Maps a width to a breakpoint class.
class ScreenSizeResolver {
  const ScreenSizeResolver._();

  static ScreenSize fromWidth(double width) {
    if (width < AppConstants.mobileBreakpoint) {
      return ScreenSize.mobile;
    }
    if (width < AppConstants.tabletBreakpoint) {
      return ScreenSize.tablet;
    }
    if (width < AppConstants.largeDesktopBreakpoint) {
      return ScreenSize.desktop;
    }
    return ScreenSize.largeDesktop;
  }
}

/// Chooses between per-breakpoint builders.
///
/// Only the selected builder runs, so an expensive desktop data grid is never
/// constructed on a phone.
class AppResponsiveLayout extends StatelessWidget {
  const AppResponsiveLayout({
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
    super.key,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;
  final WidgetBuilder? largeDesktop;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder rather than MediaQuery so this composes correctly inside
    // a constrained pane, a dialog or a master/detail split.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ScreenSize size = ScreenSizeResolver.fromWidth(
          constraints.maxWidth,
        );

        // Falls back down the chain so only `mobile` is mandatory.
        switch (size) {
          case ScreenSize.largeDesktop:
            return (largeDesktop ?? desktop ?? tablet ?? mobile)(context);
          case ScreenSize.desktop:
            return (desktop ?? tablet ?? mobile)(context);
          case ScreenSize.tablet:
            return (tablet ?? mobile)(context);
          case ScreenSize.mobile:
            return mobile(context);
        }
      },
    );
  }
}

/// Supplies a value per breakpoint without rebuilding a subtree.
class ResponsiveValue<T> {
  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  final T mobile;
  final T? tablet;
  final T? desktop;
  final T? largeDesktop;

  T resolve(BuildContext context) => resolveFor(context.screenSize);

  T resolveFor(ScreenSize size) {
    switch (size) {
      case ScreenSize.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile;
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.mobile:
        return mobile;
    }
  }
}

/// Centres content and caps its width.
///
/// A form stretched across a 2560px monitor is unusable — the eye cannot track
/// from a label on the far left to its field on the far right — so content is
/// bounded and centred while the surrounding chrome stays full width.
class AppContentContainer extends StatelessWidget {
  const AppContentContainer({
    required this.child,
    this.maxWidth = AppConstants.maxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding ?? context.pagePadding, child: child),
    ),
  );
}

/// A grid whose column count follows the breakpoint.
///
/// Used for dashboard stat tiles and form sections. Uses a `Wrap` rather than
/// a `GridView` so rows size to their content and the grid can live inside a
/// scroll view without a fixed extent.
class AppResponsiveGrid extends StatelessWidget {
  const AppResponsiveGrid({
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.largeDesktopColumns = 4,
    super.key,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int largeDesktopColumns;

  int _columnsFor(ScreenSize size) {
    switch (size) {
      case ScreenSize.largeDesktop:
        return largeDesktopColumns;
      case ScreenSize.desktop:
        return desktopColumns;
      case ScreenSize.tablet:
        return tabletColumns;
      case ScreenSize.mobile:
        return mobileColumns;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final ScreenSize size = ScreenSizeResolver.fromWidth(
        constraints.maxWidth,
      );
      final int columns = _columnsFor(size);
      final double totalSpacing = spacing * (columns - 1);
      final double itemWidth = (constraints.maxWidth - totalSpacing) / columns;

      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: children
            .map(
              (Widget child) => SizedBox(
                // Clamp so a rounding error never overflows the row.
                width: itemWidth.clamp(0.0, constraints.maxWidth),
                child: child,
              ),
            )
            .toList(growable: false),
      );
    },
  );
}
