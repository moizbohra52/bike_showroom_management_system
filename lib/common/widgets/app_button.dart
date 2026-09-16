import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:flutter/material.dart';

/// Visual weight of a button.
enum AppButtonVariant {
  /// The single main action on a screen.
  primary,

  /// A secondary action of equal importance but lower emphasis.
  secondary,

  /// A tertiary or inline action.
  ghost,

  /// A destructive action: cancel a sale, reverse a payment, delete a record.
  danger,
}

enum AppButtonSize { small, medium, large }

/// The application's button.
///
/// Wraps the Material buttons so that the loading state, the disabled state
/// and the destructive styling are handled consistently everywhere rather than
/// being re-implemented per screen.
///
/// ## Why it owns the busy state
///
/// A form submit that hits the network must not be tappable twice — on a
/// payment or a sale that would create a duplicate financial record. Passing
/// [isLoading] both shows the spinner and removes the tap handler, so the
/// guard cannot be forgotten at a call site.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.expand = false,
    this.tooltip,
    super.key,
  });

  /// Convenience constructor for the primary action.
  const AppButton.primary({
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.expand = false,
    this.tooltip,
    super.key,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.expand = false,
    this.tooltip,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.expand = false,
    this.tooltip,
    super.key,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.expand = false,
    this.tooltip,
    super.key,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;

  /// Shows a spinner and blocks further taps.
  final bool isLoading;

  /// Set false to disable for a reason other than loading, such as a missing
  /// permission or an incomplete form.
  final bool isEnabled;

  /// Fill the available width. Used for the primary action on mobile, where a
  /// full-width target is easier to hit.
  final bool expand;

  /// Explains why the button is disabled, which matters for a permission-gated
  /// action the user cannot otherwise account for.
  final String? tooltip;

  bool get _isInteractive => isEnabled && !isLoading && onPressed != null;

  EdgeInsets get _padding {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md + 2,
        );
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        );
    }
  }

  double get _iconSize {
    switch (size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 18;
      case AppButtonSize.large:
        return 20;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case AppButtonSize.small:
        return AppTypography.labelMedium;
      case AppButtonSize.medium:
      case AppButtonSize.large:
        return AppTypography.labelLarge;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget content = _buildContent(theme);
    final VoidCallback? handler = _isInteractive ? onPressed : null;

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(padding: _padding),
          child: content,
        );
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: handler,
          style: OutlinedButton.styleFrom(padding: _padding),
          child: content,
        );
      case AppButtonVariant.ghost:
        button = TextButton(
          onPressed: handler,
          style: TextButton.styleFrom(padding: _padding),
          child: content,
        );
      case AppButtonVariant.danger:
        button = FilledButton(
          onPressed: handler,
          style: FilledButton.styleFrom(
            padding: _padding,
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: content,
        );
    }

    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }

    // Only wrap in a Tooltip when there is something to say: an empty tooltip
    // still intercepts hover and long-press.
    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return Semantics(
      button: true,
      enabled: _isInteractive,
      label: label,
      child: button,
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (isLoading) {
      // Keep the label in the tree so the button does not change width when
      // it enters the busy state, which would shift the surrounding layout.
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color:
                  variant == AppButtonVariant.primary ||
                      variant == AppButtonVariant.danger
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
          AppSpacing.hGapSm,
          Text(label, style: _textStyle),
        ],
      );
    }

    if (icon == null) {
      return Text(label, style: _textStyle, textAlign: TextAlign.center);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: _iconSize),
        AppSpacing.hGapSm,
        Text(label, style: _textStyle),
      ],
    );
  }
}

/// An icon-only action, for table rows and toolbars.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.isDestructive = false,
    this.size = 20,
    super.key,
  });

  final IconData icon;

  /// Required, not optional: an icon-only control is unusable with a screen
  /// reader or unfamiliar iconography without a label.
  final String tooltip;

  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final bool isDestructive;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool interactive = isEnabled && !isLoading && onPressed != null;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: interactive ? onPressed : null,
        iconSize: size,
        visualDensity: VisualDensity.compact,
        color: isDestructive ? theme.colorScheme.error : null,
        icon: isLoading
            ? SizedBox(
                width: size,
                height: size,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
      ),
    );
  }
}
