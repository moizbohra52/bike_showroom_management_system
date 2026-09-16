import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Centralised user feedback.
///
/// Every success, warning and failure message goes through here so tone,
/// placement and duration stay consistent, and so an [AppException] is
/// rendered using its own user-facing message rather than a `toString()`.
class AppSnackbar {
  const AppSnackbar._();

  static const Duration _shortDuration = Duration(seconds: 3);
  static const Duration _longDuration = Duration(seconds: 6);

  static void success(String message, {String? title}) => _show(
    title: title ?? 'Done',
    message: message,
    icon: Icons.check_circle_outline,
    accent: AppColors.success,
    duration: _shortDuration,
  );

  static void info(String message, {String? title}) => _show(
    title: title ?? 'Information',
    message: message,
    icon: Icons.info_outline,
    accent: AppColors.info,
    duration: _shortDuration,
  );

  static void warning(String message, {String? title}) => _show(
    title: title ?? 'Please note',
    message: message,
    icon: Icons.warning_amber_outlined,
    accent: AppColors.warning,
    duration: _longDuration,
  );

  static void error(String message, {String? title}) => _show(
    title: title ?? 'Something went wrong',
    message: message,
    icon: Icons.error_outline,
    accent: AppColors.danger,
    duration: _longDuration,
  );

  /// Presents an [AppException] using its own title and message.
  ///
  /// A cancellation is deliberately silent — the user navigated away or
  /// superseded a search, and telling them their own action "failed" is noise.
  /// Validation errors are also suppressed by default, because those belong
  /// inline on the offending field, not in a transient toast the user cannot
  /// re-read while correcting the form.
  static void fromException(
    Object exception, {
    bool showValidationErrors = false,
    String? fallbackMessage,
  }) {
    if (exception is CancelledException) {
      return;
    }

    if (exception is AppException) {
      if (exception is ValidationException && !showValidationErrors) {
        return;
      }

      // Logged at warning rather than error: this is an expected, handled
      // outcome that the user has been told about.
      AppLogger.warning(
        'Surfaced ${exception.runtimeType} to the user',
        tag: 'ui',
        context: <String, Object?>{'code': exception.code},
      );

      final bool isSoft =
          exception is BusinessRuleException ||
          exception is ForbiddenException ||
          exception is ConflictException ||
          exception is OfflineException;

      if (isSoft) {
        warning(exception.message, title: exception.title);
      } else {
        error(exception.message, title: exception.title);
      }
      return;
    }

    AppLogger.error(
      'Surfaced an unmapped error to the user',
      tag: 'ui',
      error: exception,
    );
    error(fallbackMessage ?? 'An unexpected error occurred.');
  }

  static void _show({
    required String title,
    required String message,
    required IconData icon,
    required Color accent,
    required Duration duration,
  }) {
    // A snackbar raised during a route transition, or from a background
    // callback after the UI is gone, would otherwise throw.
    if (Get.context == null) {
      AppLogger.debug(
        'Suppressed snackbar with no active context: $title - $message',
        tag: 'ui',
      );
      return;
    }

    // Replace rather than stack: a burst of failures from parallel dashboard
    // queries would otherwise bury the screen in toasts.
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    final ThemeData theme = Theme.of(Get.context!);
    final bool isDark = theme.brightness == Brightness.dark;

    Get.showSnackbar(
      GetSnackBar(
        titleText: Text(title, style: AppTypography.titleSmall),
        messageText: Text(
          message,
          style: AppTypography.bodySmall.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        icon: Icon(icon, color: accent, size: 22),
        backgroundColor: isDark
            ? AppColors.darkSurfaceMuted
            : AppColors.lightSurface,
        borderColor: accent.withValues(alpha: 0.35),
        borderWidth: 1,
        borderRadius: AppRadius.md,
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        duration: duration,
        snackPosition: SnackPosition.BOTTOM,
        // Bounded so a long message never covers the form behind it.
        maxWidth: 480,
        isDismissible: true,
        dismissDirection: DismissDirection.horizontal,
        boxShadows: AppShadows.raised(isDark: isDark),
        animationDuration: const Duration(milliseconds: 250),
        forwardAnimationCurve: Curves.easeOutCubic,
      ),
    );
  }
}
