import 'dart:async';

import 'package:bike_showroom_management_system/core/constants/storage_keys.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:bike_showroom_management_system/features/auth/models/app_user_model.dart';
import 'package:bike_showroom_management_system/features/auth/models/auth_context.dart';
import 'package:bike_showroom_management_system/features/roles/models/permission_model.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:bike_showroom_management_system/services/auth_service.dart';
import 'package:bike_showroom_management_system/services/local_database_service.dart';
import 'package:bike_showroom_management_system/services/storage_service.dart';
import 'package:get/get.dart';

/// Holds the signed-in user's identity, permissions and active showroom.
///
/// Registered permanently, because almost every screen and widget reads from
/// it. It is the single place the client answers "may this user do X", and the
/// only place the active showroom is decided.
///
/// ## It is not a security boundary
///
/// Everything here is a cached projection of server-side authority, used to
/// decide what to *draw*. Row Level Security re-authorises every read and
/// write independently. Someone who patched this class would see extra
/// buttons whose requests all fail with a 403.
class SessionController extends GetxController {
  SessionController({
    required this.authService,
    required this.storageService,
    required this.localDatabaseService,
  });

  final AuthService authService;
  final StorageService storageService;
  final LocalDatabaseService localDatabaseService;

  static SessionController get instance => Get.find<SessionController>();

  /// The resolved context, or null while signed out.
  final Rx<AuthContext?> context = Rx<AuthContext?>(null);

  /// Showroom currently selected in the switcher.
  final RxnString activeShowroomId = RxnString();

  final RxBool isRestoring = true.obs;

  /// Set when the account exists but is not usable — no role, no showroom, or
  /// deactivated. The shell shows a blocked-account screen instead of the app.
  final RxnString provisioningIssue = RxnString();

  static const String _sessionCacheKey = 'auth_context';

  // ------------------------------------------------------------- derived state

  bool get isSignedIn => context.value != null;

  AppUserModel? get user => context.value?.user;

  String? get userId => user?.id;

  String get userName => user?.name ?? '';

  PermissionSet get permissions =>
      context.value?.permissions ?? const PermissionSet.empty();

  bool get isSuperAdmin => context.value?.isSuperAdmin ?? false;

  List<ShowroomModel> get showrooms =>
      context.value?.showrooms ?? const <ShowroomModel>[];

  ShowroomModel? get activeShowroom {
    final String? id = activeShowroomId.value;
    if (id == null) {
      return null;
    }
    for (final ShowroomModel showroom in showrooms) {
      if (showroom.id == id) {
        return showroom;
      }
    }
    return null;
  }

  bool get canSwitchShowroom => showrooms.length > 1;

  bool get isBlocked => provisioningIssue.value != null;

  // -------------------------------------------------------- permission checks

  /// Whether the user holds [permission] (`module.action`).
  bool can(String permission) => permissions.has(permission);

  bool canAny(Iterable<String> keys) => permissions.hasAny(keys);

  bool canAll(Iterable<String> keys) => permissions.hasAll(keys);

  bool canAccessModule(String module) => permissions.canAccessModule(module);

  /// Throws when [permission] is absent.
  ///
  /// Used at the top of a controller action so an unauthorised path fails with
  /// a clear message rather than producing a confusing server error further
  /// down. The server check still happens regardless.
  void requirePermission(String permission) {
    if (!can(permission)) {
      AppLogger.warning(
        'Blocked local action, missing permission',
        tag: 'rbac',
        context: <String, Object?>{'permission': permission, 'userId': userId},
      );
      throw PermissionDeniedException(permission: permission);
    }
  }

  bool canAccessShowroom(String? showroomId) =>
      context.value?.canAccessShowroom(showroomId) ?? false;

  // ----------------------------------------------------------------- lifecycle

  @override
  void onInit() {
    super.onInit();
    _restoreCachedContext();
  }

  /// Loads the last known context so the shell can render its navigation on
  /// the first frame rather than flashing an empty skeleton.
  ///
  /// This is presentation only. Nothing is trusted from it: `establish()`
  /// overwrites it with a freshly resolved context as soon as the network
  /// answers, and every request is authorised server-side either way.
  Future<void> _restoreCachedContext() async {
    try {
      final Map<String, Object?>? cached = await localDatabaseService.database
          .get(HiveBoxes.session, _sessionCacheKey);
      final AuthContext? restored = AuthContext.fromCacheJson(cached);

      if (restored != null && authService.isSignedIn) {
        context.value = restored;
        activeShowroomId.value = _resolveInitialShowroom(restored);
        AppLogger.debug(
          'Restored cached auth context for ${restored.user.name}',
          tag: 'session',
        );
      }
    } on Object catch (error) {
      AppLogger.warning(
        'Could not restore cached auth context',
        tag: 'session',
        error: error,
      );
    } finally {
      isRestoring.value = false;
    }
  }

  /// Installs a freshly resolved context and persists it for the next launch.
  Future<void> establish(AuthContext resolved) async {
    final String? issue = resolved.provisioningIssue;
    provisioningIssue.value = issue;

    context.value = resolved;
    activeShowroomId.value = _resolveInitialShowroom(resolved);

    if (issue != null) {
      AppLogger.warning(
        'Account is not fully provisioned',
        tag: 'session',
        context: <String, Object?>{'issue': issue, 'userId': resolved.user.id},
      );
      return;
    }

    await _persist();

    final String? showroomId = activeShowroomId.value;
    if (showroomId != null) {
      await storageService.setSelectedShowroomId(showroomId);
    }

    AppLogger.info(
      'Session established for ${resolved.user.name}',
      tag: 'session',
      context: <String, Object?>{
        'roles': resolved.user.roleNames,
        'activeShowroom': showroomId,
      },
    );
  }

  /// Chooses the showroom to start in.
  ///
  /// Prefers the one the user last selected, but only if they still have
  /// access — an administrator may have moved them since. Falls back to their
  /// home showroom, then to the first they can reach.
  String? _resolveInitialShowroom(AuthContext resolved) {
    final String? remembered = storageService.selectedShowroomId;
    if (remembered != null && resolved.canAccessShowroom(remembered)) {
      return remembered;
    }
    final String? home = resolved.user.showroomId;
    if (home != null && resolved.canAccessShowroom(home)) {
      return home;
    }
    if (resolved.showrooms.isNotEmpty) {
      return resolved.showrooms.first.id;
    }
    return null;
  }

  /// Switches the active showroom.
  ///
  /// Rejects a showroom outside the user's assignments. Even if this were
  /// bypassed, every query carries the showroom as a filter *and* is checked
  /// by `can_access_showroom()` in the RLS policy, so no data would be
  /// returned for a showroom the user cannot see.
  Future<void> switchShowroom(String showroomId) async {
    if (!canAccessShowroom(showroomId)) {
      throw ForbiddenException(
        message: 'You do not have access to that showroom.',
      );
    }
    if (activeShowroomId.value == showroomId) {
      return;
    }

    activeShowroomId.value = showroomId;
    await storageService.setSelectedShowroomId(showroomId);

    final AuthContext? current = context.value;
    if (current != null) {
      context.value = current.copyWith(activeShowroomId: showroomId);
      await _persist();
    }

    AppLogger.info(
      'Switched active showroom',
      tag: 'session',
      context: <String, Object?>{'showroomId': showroomId},
    );

    // Cached data is showroom-scoped, so it must not bleed across a switch.
    await localDatabaseService.clearUserScopedCaches();
  }

  /// Re-resolves the context from the server.
  ///
  /// Called after a role or showroom assignment changes, and on resume when
  /// the cached context is older than the session.
  ///
  /// Named distinctly from `GetxController.refresh()`, which triggers a widget
  /// rebuild and would be shadowed by an override here.
  Future<void> refreshContext() async {
    if (!authService.isSignedIn) {
      return;
    }
    try {
      final AuthContext resolved = await authService.resolveContext();
      await establish(resolved);
    } on Object catch (error) {
      AppLogger.warning(
        'Could not refresh auth context',
        tag: 'session',
        error: error,
      );
    }
  }

  Future<void> _persist() async {
    final AuthContext? current = context.value;
    if (current == null) {
      return;
    }
    try {
      await localDatabaseService.database.put(
        HiveBoxes.session,
        _sessionCacheKey,
        current.toCacheJson(),
      );
    } on Object catch (error) {
      AppLogger.warning(
        'Could not persist auth context',
        tag: 'session',
        error: error,
      );
    }
  }

  /// Clears every trace of the signed-in user.
  Future<void> clear() async {
    context.value = null;
    activeShowroomId.value = null;
    provisioningIssue.value = null;

    try {
      await localDatabaseService.database.delete(
        HiveBoxes.session,
        _sessionCacheKey,
      );
      await localDatabaseService.clearUserScopedCaches();
      await storageService.clearUserScopedData();
    } on Object catch (error) {
      AppLogger.warning(
        'Error while clearing session state',
        tag: 'session',
        error: error,
      );
    }

    AppLogger.clearHistory();
    AppLogger.info('Session cleared', tag: 'session');
  }
}
