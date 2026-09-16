import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Rejects navigation to a route the user lacks the permission for.
///
/// Reads the required permission from [AppRoutes.routePermissions], so the
/// guard is declarative and every route — including one reached by deep link
/// or a typed URL — is checked the same way.
///
/// ## This is a usability guard, not the security boundary
///
/// It prevents a user from landing on a screen whose every query would fail.
/// The actual enforcement is Row Level Security: bypassing this middleware
/// would render an empty screen, not leak data.
class PermissionMiddleware extends GetMiddleware {
  PermissionMiddleware({this.requiredPermission, this.anyOfPermissions});

  /// Overrides the lookup in [AppRoutes.routePermissions]. Used for a route
  /// that needs a permission the map cannot express.
  final String? requiredPermission;

  /// Passes when the user holds **any** of these, for a screen that serves
  /// more than one operation.
  ///
  /// A create/edit form is the case that needs it. Guarding it on
  /// `<module>.create` alone locks out a role that may edit but not create —
  /// SERVICE MANAGER, for instance, holds `customers.edit` without
  /// `customers.create`, and would be bounced to the dashboard on tapping
  /// Edit. The form's own controller still checks the specific permission for
  /// the operation actually being performed, and RLS decides the outcome
  /// regardless.
  final List<String>? anyOfPermissions;

  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    if (route == null || AppRoutes.isPublic(route)) {
      return null;
    }
    if (!Get.isRegistered<SessionController>()) {
      return null;
    }

    final List<String>? anyOf = anyOfPermissions;
    final String? permission =
        requiredPermission ?? AppRoutes.permissionFor(route);
    if (permission == null && (anyOf == null || anyOf.isEmpty)) {
      return null;
    }

    final SessionController session = Get.find<SessionController>();
    if (!session.isSignedIn) {
      // AuthMiddleware owns this case; do not double-redirect.
      return null;
    }

    final bool allowed = anyOf != null && anyOf.isNotEmpty
        ? session.canAny(anyOf)
        : session.can(permission!);
    if (allowed) {
      return null;
    }

    AppLogger.warning(
      'Blocked navigation: missing permission',
      tag: 'routing',
      context: <String, Object?>{
        'route': route,
        'permission': anyOf?.join(' | ') ?? permission,
        'userId': session.userId,
      },
    );

    // Send them somewhere they can actually use rather than a dead end.
    return RouteSettings(name: _fallbackFor(session));
  }

  /// Picks a landing route the user is allowed to see.
  ///
  /// A user without `dashboard.view` — a technician, for instance — would
  /// otherwise be redirected into another blocked route and bounce.
  String _fallbackFor(SessionController session) {
    if (session.can(AppRoutes.routePermissions[AppRoutes.dashboard]!)) {
      return AppRoutes.dashboard;
    }
    for (final MapEntry<String, String> entry
        in AppRoutes.routePermissions.entries) {
      if (session.can(entry.value)) {
        return entry.key;
      }
    }
    return AppRoutes.accountBlocked;
  }
}
