import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/config/environment_config.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:bike_showroom_management_system/features/auth/models/auth_context.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:bike_showroom_management_system/services/auth_service.dart';
import 'package:get/get.dart';

/// Runs the startup sequence and decides the landing route.
///
/// The order matters and is the reason this is a controller rather than a few
/// lines in `main()`:
///
///  1. Verify the build is configured at all.
///  2. Determine whether a persisted session exists.
///  3. Resolve the authorisation context from the server — a stored session
///     says who the user *was*, not what they may do now. A role revoked
///     while the app was closed must take effect on this launch.
///  4. Confirm the account is still provisioned and active.
///  5. Route accordingly.
///
/// Step 3 is why the app does not simply trust a cached context to enter the
/// dashboard: the cache exists to render navigation without a blank frame, not
/// to grant access.
class SplashController extends GetxController {
  SplashController({
    required this.authService,
    required this.sessionController,
  });

  final AuthService authService;
  final SessionController sessionController;

  final RxString statusMessage = 'Starting up...'.obs;

  /// Set when startup cannot proceed. Surfaced on the splash screen with a
  /// retry, because the usual cause is a misconfigured build or a dead
  /// network, both of which the user needs told about.
  final RxnString fatalError = RxnString();

  @override
  void onReady() {
    super.onReady();
    bootstrap();
  }

  Future<void> bootstrap() async {
    fatalError.value = null;

    try {
      statusMessage.value = 'Checking configuration...';
      if (!EnvironmentConfig.isConfigured) {
        fatalError.value =
            'This build is missing required configuration '
            '(${EnvironmentConfig.missingKeys.join(', ')}). '
            'Please reinstall from an official build.';
        AppLogger.critical(
          'Startup aborted: build is not configured',
          tag: 'startup',
          context: EnvironmentConfig.diagnostics,
        );
        return;
      }

      statusMessage.value = 'Restoring your session...';

      if (!authService.isSignedIn) {
        await _goTo(AppRoutes.login);
        return;
      }

      statusMessage.value = 'Checking your access...';

      // Always re-resolve from the server. A cached context is for rendering,
      // never for authorisation.
      final AuthContext context = await authService.resolveContext();
      await sessionController.establish(context);

      if (context.provisioningIssue != null) {
        await _goTo(AppRoutes.accountBlocked);
        return;
      }

      statusMessage.value = 'Almost there...';
      await _goTo(_landingRouteFor(context));
    } on UnauthorizedException {
      // The stored refresh token is spent. Clear and start clean.
      AppLogger.info(
        'Stored session is no longer valid; signing out',
        tag: 'startup',
      );
      await authService.signOut();
      await sessionController.clear();
      await _goTo(AppRoutes.login);
    } on ForbiddenException catch (error) {
      // Authenticated, but the profile is not usable.
      AppLogger.warning(
        'Account is not permitted to use the application',
        tag: 'startup',
        error: error,
      );
      await sessionController.clear();
      await authService.signOut();
      fatalError.value = error.message;
    } on NetworkException catch (error) {
      await _handleOfflineStart(error);
    } on OfflineException catch (error) {
      await _handleOfflineStart(error);
    } on RequestTimeoutException catch (error) {
      await _handleOfflineStart(error);
    } on AppException catch (error, stackTrace) {
      AppLogger.error(
        'Startup failed',
        tag: 'startup',
        error: error,
        stackTrace: stackTrace,
      );
      fatalError.value = error.message;
    } on Object catch (error, stackTrace) {
      AppLogger.critical(
        'Unhandled startup failure',
        tag: 'startup',
        error: error,
        stackTrace: stackTrace,
      );
      fatalError.value =
          'Something went wrong while starting up. Please try again.';
    }
  }

  /// Starting up with no connection.
  ///
  /// If a cached context was restored, the user is let in to work offline —
  /// that is the whole point of the offline mode, and the cache only decides
  /// what is *drawn*; any request made will still be authorised when it
  /// eventually reaches the server. With no cache there is nothing to show, so
  /// the failure is surfaced with a retry.
  Future<void> _handleOfflineStart(AppException error) async {
    if (sessionController.isSignedIn && EnvironmentConfig.enableOfflineMode) {
      AppLogger.warning(
        'Starting offline with a cached session',
        tag: 'startup',
        error: error,
      );
      await _goTo(AppRoutes.dashboard);
      return;
    }
    fatalError.value =
        'No connection. Please check your network and try again.';
  }

  /// Chooses a landing route the user can actually open.
  ///
  /// A technician has no `dashboard.view`, so sending everyone to the
  /// dashboard would bounce them through the permission guard on every launch.
  String _landingRouteFor(AuthContext context) {
    if (context.has(AppRoutes.routePermissions[AppRoutes.dashboard]!)) {
      return AppRoutes.dashboard;
    }
    for (final MapEntry<String, String> entry
        in AppRoutes.routePermissions.entries) {
      if (context.has(entry.value)) {
        return entry.key;
      }
    }
    return AppRoutes.accountBlocked;
  }

  Future<void> _goTo(String route) async {
    // A frame is allowed to settle first so the splash does not flash away
    // before it has painted, which reads as a glitch on a fast start.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await Get.offAllNamed(route);
  }
}
