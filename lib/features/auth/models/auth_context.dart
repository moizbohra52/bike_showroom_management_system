import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/features/auth/models/app_user_model.dart';
import 'package:bike_showroom_management_system/features/roles/models/permission_model.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';

/// The fully resolved identity and authorisation context for the signed-in
/// user.
///
/// Assembled once at sign-in by a single call to `current_user_context()`,
/// which walks the chain the specification defines:
///
/// ```
/// auth.uid() -> users -> user_roles -> roles -> role_permissions
///            -> permissions -> accessible showrooms
/// ```
///
/// Doing this in one server-side round trip rather than five client queries
/// matters: those five queries would each be subject to RLS policies that
/// themselves need the user's context, which is how recursive policy
/// evaluation deadlocks arise. The security-definer function breaks that cycle.
class AuthContext {
  const AuthContext({
    required this.user,
    required this.permissions,
    this.showrooms = const <ShowroomModel>[],
    this.activeShowroomId,
    this.resolvedAt,
  });

  /// Parses the payload of `current_user_context()`.
  factory AuthContext.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    final Map<String, Object?>? userJson = reader.objectOrNull('user');
    if (userJson == null) {
      throw const FormatException(
        'current_user_context() returned no user profile',
      );
    }
    final AppUserModel user = AppUserModel.fromJson(userJson);

    final List<ShowroomModel> showrooms = reader
        .objectList('showrooms')
        .map(ShowroomModel.fromJson)
        .toList(growable: false);

    // The function returns the flat permission key list; a super admin gets
    // the implicit-all form instead of an enumerated list.
    final bool superAdmin =
        reader.boolean('is_super_admin') || user.isSuperAdmin;
    final PermissionSet permissions = superAdmin
        ? PermissionSet.superAdmin()
        : PermissionSet(reader.stringList('permissions'));

    return AuthContext(
      user: user,
      permissions: permissions,
      showrooms: showrooms,
      activeShowroomId:
          reader.stringOrNull('active_showroom_id') ?? user.showroomId,
      resolvedAt: DateTime.now(),
    );
  }

  final AppUserModel user;

  /// Union of the permissions granted by every role the user holds.
  final PermissionSet permissions;

  /// Showrooms the user may act within, already filtered server-side.
  final List<ShowroomModel> showrooms;

  /// The showroom currently selected in the switcher.
  final String? activeShowroomId;

  /// When this context was built, so a stale one can be refreshed after a
  /// role change.
  final DateTime? resolvedAt;

  bool get isSuperAdmin => permissions.isSuperAdmin || user.isSuperAdmin;

  bool get isActive => user.isActive;

  List<RoleModel> get roles => user.roles;

  /// The active showroom object, or null while none is selected.
  ShowroomModel? get activeShowroom {
    if (activeShowroomId == null) {
      return null;
    }
    for (final ShowroomModel showroom in showrooms) {
      if (showroom.id == activeShowroomId) {
        return showroom;
      }
    }
    return null;
  }

  bool get hasShowroomAccess => showrooms.isNotEmpty;

  bool get canSwitchShowroom => showrooms.length > 1;

  /// Whether the user is fully provisioned. A profile can exist without a role
  /// or a showroom, because the auth trigger creates it before an
  /// administrator completes onboarding. Such a user must not reach the app.
  bool get isFullyProvisioned =>
      isActive &&
      user.roles.isNotEmpty &&
      (isSuperAdmin || showrooms.isNotEmpty);

  /// Explains what onboarding step is missing, for the blocked-account screen.
  String? get provisioningIssue {
    if (!isActive) {
      return 'Your account is ${user.status.label.toLowerCase()}. '
          'Please contact your administrator.';
    }
    if (user.roles.isEmpty) {
      return 'No role has been assigned to your account yet. '
          'Please contact your administrator.';
    }
    if (!isSuperAdmin && showrooms.isEmpty) {
      return 'You have not been assigned to a showroom yet. '
          'Please contact your administrator.';
    }
    return null;
  }

  bool has(String permission) => permissions.has(permission);

  bool hasAny(Iterable<String> keys) => permissions.hasAny(keys);

  bool hasAll(Iterable<String> keys) => permissions.hasAll(keys);

  bool canAccessModule(String module) => permissions.canAccessModule(module);

  bool canAccessShowroom(String? showroomId) {
    if (isSuperAdmin) {
      return true;
    }
    if (showroomId == null) {
      return false;
    }
    return showrooms.any((ShowroomModel s) => s.id == showroomId);
  }

  AuthContext copyWith({
    AppUserModel? user,
    PermissionSet? permissions,
    List<ShowroomModel>? showrooms,
    String? activeShowroomId,
  }) => AuthContext(
    user: user ?? this.user,
    permissions: permissions ?? this.permissions,
    showrooms: showrooms ?? this.showrooms,
    activeShowroomId: activeShowroomId ?? this.activeShowroomId,
    resolvedAt: resolvedAt,
  );

  /// Cached form, so the application shell can render its navigation on the
  /// first frame after a cold start instead of waiting on the network.
  ///
  /// Restoring this never grants access: it only decides which menu entries
  /// are drawn. The server re-authorises every request regardless.
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'user': user.toCacheJson(),
    'permissions': permissions.toJson(),
    'is_super_admin': isSuperAdmin,
    'showrooms': showrooms
        .map((ShowroomModel showroom) => showroom.toCacheJson())
        .toList(),
    'active_showroom_id': activeShowroomId,
    'resolved_at': resolvedAt?.toIso8601String(),
  };

  /// Restores from [toCacheJson].
  static AuthContext? fromCacheJson(Map<String, Object?>? json) {
    if (json == null) {
      return null;
    }
    try {
      final JsonReader reader = JsonReader(json);
      final Map<String, Object?>? userJson = reader.objectOrNull('user');
      if (userJson == null) {
        return null;
      }
      final bool superAdmin = reader.boolean('is_super_admin');
      return AuthContext(
        user: AppUserModel.fromJson(userJson),
        permissions: superAdmin
            ? PermissionSet.superAdmin()
            : PermissionSet(reader.stringList('permissions')),
        showrooms: reader
            .objectList('showrooms')
            .map(ShowroomModel.fromJson)
            .toList(growable: false),
        activeShowroomId: reader.stringOrNull('active_showroom_id'),
        resolvedAt: reader.timestampOrNull('resolved_at'),
      );
    } on Object {
      // A cache that cannot be parsed is simply discarded; the context will be
      // re-resolved from the server.
      return null;
    }
  }

  @override
  String toString() =>
      'AuthContext(${user.name}, '
      '${permissions.length} permissions, '
      '${showrooms.length} showrooms, active: $activeShowroomId)';
}
