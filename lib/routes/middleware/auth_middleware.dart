import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:bike_showroom_management_system/services/auth_service.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Blocks protected routes when there is no usable session.
///
/// Runs before [PermissionMiddleware], so an unauthenticated deep link is
/// redirected to the login screen rather than reported as a permission
/// failure. On web this also covers a URL typed directly into the address bar.
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (route == null || AppRoutes.isPublic(route)) {
      return null;
    }

    // The services may not be registered yet during a very early redirect.
    if (!Get.isRegistered<AuthService>() ||
        !Get.isRegistered<SessionController>()) {
      return const RouteSettings(name: AppRoutes.splash);
    }

    final AuthService authService = Get.find<AuthService>();
    if (!authService.isSignedIn) {
      AppLogger.info(
        'Redirecting unauthenticated access to $route',
        tag: 'routing',
      );
      return const RouteSettings(name: AppRoutes.login);
    }

    final SessionController session = Get.find<SessionController>();

    // Authenticated but the profile is not usable: no role, no showroom, or
    // deactivated. Such a user must not reach any business screen.
    if (session.isBlocked && route != AppRoutes.accountBlocked) {
      return const RouteSettings(name: AppRoutes.accountBlocked);
    }

    // Signed in but the context has not resolved yet — send to splash, which
    // owns the bootstrap sequence.
    if (!session.isSignedIn && !session.isBlocked) {
      return const RouteSettings(name: AppRoutes.splash);
    }

    return null;
  }
}

/// Keeps a signed-in user out of the authentication screens.
///
/// Without this, the back button from the dashboard would land on the login
/// form while still authenticated, which is confusing and invites a
/// double-sign-in.
class GuestOnlyMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AuthService>()) {
      return null;
    }
    // A password-recovery deep link arrives with a temporary session, so the
    // reset screen must stay reachable while signed in.
    if (route == AppRoutes.resetPassword) {
      return null;
    }
    if (Get.find<AuthService>().isSignedIn) {
      return const RouteSettings(name: AppRoutes.dashboard);
    }
    return null;
  }
}
