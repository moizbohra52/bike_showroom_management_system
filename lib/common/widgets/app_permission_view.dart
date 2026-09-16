import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Renders [child] only when the user holds the required permission.
///
/// The declarative alternative to scattering `if (session.can(...))` through
/// build methods. Wrapping an action in this cannot be forgotten at review
/// time the way an inline conditional can.
///
/// ## Hide or disable
///
/// Both are supported because the right answer differs. Hiding is correct for
/// a navigation entry or a whole section — showing a manager a "Approve
/// Expense" tab they can never use is clutter. Disabling with a tooltip is
/// better for an action inside a row the user *can* see, where the control
/// vanishing would make the UI look broken or inconsistent between rows.
///
/// Neither is a security measure. The server re-authorises every request, so a
/// user who forced the widget to render would simply get a 403.
class AppPermissionView extends StatelessWidget {
  const AppPermissionView({
    required String this.permission,
    required this.child,
    this.fallback,
    this.showDenied = false,
    super.key,
  }) : allPermissions = null,
       anyPermissions = null;

  /// Requires every listed permission.
  const AppPermissionView.all({
    required List<String> permissions,
    required this.child,
    this.fallback,
    this.showDenied = false,
    super.key,
  }) : permission = null,
       allPermissions = permissions,
       anyPermissions = null;

  /// Requires at least one of the listed permissions. Used for a section that
  /// contains several independently gated screens.
  const AppPermissionView.any({
    required List<String> permissions,
    required this.child,
    this.fallback,
    this.showDenied = false,
    super.key,
  }) : permission = null,
       allPermissions = null,
       anyPermissions = permissions;

  final String? permission;
  final List<String>? allPermissions;
  final List<String>? anyPermissions;

  final Widget child;

  /// Rendered instead of [child] when the check fails. Defaults to nothing.
  final Widget? fallback;

  /// Show an explicit "not permitted" panel rather than hiding silently.
  /// Appropriate for a full screen reached by deep link, where an empty page
  /// would be baffling.
  final bool showDenied;

  bool _isAllowed(SessionController session) {
    if (permission != null) {
      return session.can(permission!);
    }
    if (allPermissions != null) {
      return session.canAll(allPermissions!);
    }
    if (anyPermissions != null) {
      return session.canAny(anyPermissions!);
    }
    // No requirement expressed means no restriction.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SessionController>()) {
      return fallback ?? const SizedBox.shrink();
    }

    final SessionController session = Get.find<SessionController>();

    // Observed so the tree updates if the context is refreshed after an
    // administrator changes the user's role mid-session.
    return Obx(() {
      // Touch the observable so Obx subscribes even on the allowed path.
      final bool _ = session.context.value != null;
      final bool allowed = _isAllowed(session);

      if (allowed) {
        return child;
      }
      if (fallback != null) {
        return fallback!;
      }
      if (showDenied) {
        return AppErrorState(
          error: ForbiddenException(
            message: 'You do not have permission to view this section.',
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }
}

/// Disables its child when the permission is absent, with an explanatory
/// tooltip, instead of removing it.
class AppPermissionGate extends StatelessWidget {
  const AppPermissionGate({
    required this.permission,
    required this.builder,
    this.deniedTooltip,
    super.key,
  });

  final String permission;

  /// Receives whether the action is permitted, so the caller can pass it to a
  /// button's `isEnabled` and render the right tooltip.
  final Widget Function(BuildContext context, bool isAllowed, String? tooltip)
  builder;

  final String? deniedTooltip;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SessionController>()) {
      return builder(context, false, deniedTooltip);
    }
    final SessionController session = Get.find<SessionController>();

    return Obx(() {
      final bool _ = session.context.value != null;
      final bool allowed = session.can(permission);
      return builder(
        context,
        allowed,
        allowed
            ? null
            : (deniedTooltip ??
                  'You do not have permission to perform this action'),
      );
    });
  }
}
