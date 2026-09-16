import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:flutter/material.dart';

/// A centred loading indicator with an optional message.
class AppLoader extends StatelessWidget {
  const AppLoader({this.message, this.size = 28, super.key});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 2.5),
        ),
        if (message != null) ...<Widget>[
          AppSpacing.gapLg,
          Text(
            message!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ),
  );
}

/// An inline loader for a button row or a list footer.
class AppInlineLoader extends StatelessWidget {
  const AppInlineLoader({this.size = 16, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: const CircularProgressIndicator(strokeWidth: 2),
  );
}

/// Shown when a list has no rows.
///
/// Distinguishes "nothing exists yet" from "nothing matched your filters",
/// because the useful action differs: create a record, or clear the filter.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    super.key,
  });

  /// The filtered variant, offering to clear the filters.
  const AppEmptyState.filtered({
    this.title = 'No matching records',
    this.message =
        'No records match the current search and filters. Try widening them.',
    this.icon = Icons.filter_alt_off_outlined,
    this.actionLabel = 'Clear filters',
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              AppSpacing.gapLg,
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...<Widget>[
                AppSpacing.gapSm,
                Text(
                  message!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...<Widget>[
                AppSpacing.gapXl,
                AppButton.primary(
                  label: actionLabel!,
                  onPressed: onAction,
                  size: AppButtonSize.small,
                ),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...<Widget>[
                AppSpacing.gapSm,
                AppButton.ghost(
                  label: secondaryActionLabel!,
                  onPressed: onSecondaryAction,
                  size: AppButtonSize.small,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a load failed.
///
/// Takes the [AppException] rather than a string so it can present the right
/// title, decide whether to offer a retry, and tailor the icon — a permission
/// failure and a dropped connection call for different responses, and a retry
/// button on a 403 just invites the user to fail again.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.error,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final AppException error;
  final VoidCallback? onRetry;

  /// A tighter layout for use inside a card or a list footer.
  final bool compact;

  IconData get _icon {
    if (error is NetworkException || error is OfflineException) {
      return Icons.wifi_off_outlined;
    }
    if (error is ForbiddenException || error is PermissionDeniedException) {
      return Icons.lock_outline;
    }
    if (error is UnauthorizedException) {
      return Icons.person_off_outlined;
    }
    if (error is NotFoundException) {
      return Icons.search_off_outlined;
    }
    if (error is RequestTimeoutException) {
      return Icons.timer_off_outlined;
    }
    if (error is ValidationException || error is BusinessRuleException) {
      return Icons.rule_outlined;
    }
    return Icons.error_outline;
  }

  /// A retry is only offered when repeating the request could plausibly work.
  bool get _canRetry => onRetry != null && error.isRetryable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = error is ForbiddenException
        ? AppColors.warning
        : theme.colorScheme.error;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Icon(_icon, size: 18, color: accent),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(error.message, style: theme.textTheme.bodySmall),
            ),
            if (_canRetry) ...<Widget>[
              AppSpacing.hGapSm,
              AppButton.ghost(
                label: 'Retry',
                onPressed: onRetry,
                size: AppButtonSize.small,
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 30, color: accent),
              ),
              AppSpacing.gapLg,
              Text(
                error.title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
              Text(
                error.message,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (_canRetry) ...<Widget>[
                AppSpacing.gapXl,
                AppButton.secondary(
                  label: 'Try again',
                  icon: Icons.refresh,
                  onPressed: onRetry,
                  size: AppButtonSize.small,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves the four states a data-backed screen can be in.
///
/// Centralising the precedence prevents the common bug of showing an empty
/// state while a refresh is still running, or an error while stale data is
/// perfectly displayable.
class AppAsyncBuilder<T> extends StatelessWidget {
  const AppAsyncBuilder({
    required this.isLoading,
    required this.error,
    required this.isEmpty,
    required this.builder,
    this.onRetry,
    this.emptyState,
    this.loadingMessage,
    this.hasData = false,
    super.key,
  });

  final bool isLoading;
  final AppException? error;
  final bool isEmpty;
  final WidgetBuilder builder;
  final VoidCallback? onRetry;
  final Widget? emptyState;
  final String? loadingMessage;

  /// Whether previously loaded data is available. When true, a refresh keeps
  /// showing that data instead of replacing the screen with a spinner.
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    // Stale data beats a spinner: replacing a populated table with a loader on
    // every refresh makes the screen flicker and loses the scroll position.
    if (isLoading && !hasData) {
      return AppLoader(message: loadingMessage);
    }
    if (error != null && !hasData) {
      return AppErrorState(error: error!, onRetry: onRetry);
    }
    if (isEmpty && !isLoading) {
      return emptyState ??
          const AppEmptyState(title: 'Nothing to show here yet');
    }
    return builder(context);
  }
}
