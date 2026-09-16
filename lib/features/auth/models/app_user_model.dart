import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';

/// A row from `users` — the application profile, distinct from the Supabase
/// Auth user.
///
/// The split is deliberate. `auth.users` is owned by Supabase and holds the
/// credential; `public.users` holds the business profile, the showroom
/// assignment and the role links. They are joined by `auth_user_id`. Keeping
/// them separate means an administrator can deactivate a user, reassign their
/// showroom or change their role without touching the auth system, and the
/// RLS helper functions can resolve authorisation with a single lookup.
class AppUserModel implements SyncableModel {
  const AppUserModel({
    required this.id,
    required this.authUserId,
    required this.name,
    this.showroomId,
    this.email,
    this.phone,
    this.status = UserStatus.active,
    this.avatarUrl,
    this.employeeCode,
    this.designation,
    this.roles = const <RoleModel>[],
    this.accessibleShowroomIds = const <String>[],
    this.lastLoginAt,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory AppUserModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    /// Roles arrive either directly or through the `user_roles` join.
    List<RoleModel> parseRoles() {
      final List<Map<String, Object?>> direct = reader.objectList('roles');
      if (direct.isNotEmpty) {
        return direct.map(RoleModel.fromJson).toList(growable: false);
      }
      final List<Map<String, Object?>> viaJoin = reader.objectList(
        'user_roles',
      );
      final List<RoleModel> result = <RoleModel>[];
      for (final Map<String, Object?> link in viaJoin) {
        final Map<String, Object?>? role = JsonReader(
          link,
        ).objectOrNull('roles');
        if (role != null) {
          result.add(RoleModel.fromJson(role));
        }
      }
      return result;
    }

    /// Additional showrooms granted through `user_showrooms`, beyond the
    /// user's home `showroom_id`.
    List<String> parseAccessibleShowrooms() {
      final List<String> ids = <String>[];
      final String? home = reader.stringOrNull('showroom_id');
      if (home != null) {
        ids.add(home);
      }
      for (final Map<String, Object?> link in reader.objectList(
        'user_showrooms',
      )) {
        final String? id = JsonReader(link).stringOrNull('showroom_id');
        if (id != null && !ids.contains(id)) {
          ids.add(id);
        }
      }
      // A flattened array form, as returned by `current_user_context()`.
      for (final String id in reader.stringList('accessible_showroom_ids')) {
        if (!ids.contains(id)) {
          ids.add(id);
        }
      }
      return ids;
    }

    return AppUserModel(
      id: reader.requireString('id'),
      authUserId: reader.string('auth_user_id'),
      name: reader.string('name'),
      showroomId: reader.stringOrNull('showroom_id'),
      email: reader.stringOrNull('email'),
      phone: reader.stringOrNull('phone'),
      status: UserStatus.fromValue(reader.stringOrNull('status')),
      avatarUrl: reader.stringOrNull('avatar_url'),
      employeeCode: reader.stringOrNull('employee_code'),
      designation: reader.stringOrNull('designation'),
      roles: parseRoles(),
      accessibleShowroomIds: parseAccessibleShowrooms(),
      lastLoginAt: reader.timestampOrNull('last_login_at'),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  /// Foreign key to `auth.users.id`.
  final String authUserId;

  final String name;

  /// Home showroom. Null only for a SUPER ADMIN, who is not scoped to one.
  final String? showroomId;

  final String? email;
  final String? phone;
  final UserStatus status;
  final String? avatarUrl;
  final String? employeeCode;
  final String? designation;

  final List<RoleModel> roles;

  /// Every showroom this user may read, home showroom first.
  final List<String> accessibleShowroomIds;

  final DateTime? lastLoginAt;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isActive => status.canSignIn;

  bool get isSuperAdmin => roles.any((RoleModel role) => role.isSuperAdmin);

  /// The most authoritative role held, used to choose a dashboard layout.
  RoleModel? get primaryRole {
    if (roles.isEmpty) {
      return null;
    }
    final List<RoleModel> sorted = List<RoleModel>.from(roles)
      ..sort((RoleModel a, RoleModel b) => a.rank.compareTo(b.rank));
    return sorted.first;
  }

  AppRole? get primaryAppRole => primaryRole?.appRole;

  List<String> get roleNames =>
      roles.map((RoleModel role) => role.name).toList(growable: false);

  String get roleLabel => roles.isEmpty
      ? 'No role assigned'
      : roles.map((RoleModel role) => role.label).join(', ');

  /// Whether the user may act on [candidateShowroomId].
  ///
  /// A convenience for shaping the UI. Row Level Security enforces the same
  /// rule server-side via `can_access_showroom()`, so this returning true
  /// incorrectly would produce a failed request, not unauthorised access.
  bool canAccessShowroom(String? candidateShowroomId) {
    if (isSuperAdmin) {
      return true;
    }
    if (candidateShowroomId == null) {
      return false;
    }
    return accessibleShowroomIds.contains(candidateShowroomId);
  }

  bool get hasMultipleShowrooms =>
      isSuperAdmin || accessibleShowroomIds.length > 1;

  /// Initials for the avatar fallback.
  String get initials {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  /// Write payload.
  ///
  /// `auth_user_id` is excluded: it is set once by the post-signup trigger and
  /// re-pointing it would let one profile hijack another's credential.
  /// Role assignment is a separate operation against `user_roles`, guarded by
  /// `users.assign`.
  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'name': name.trim(),
    'showroom_id': showroomId,
    'email': email?.trim().toLowerCase(),
    'phone': phone,
    'status': status.value,
    'avatar_url': avatarUrl,
    'employee_code': employeeCode,
    'designation': designation,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'auth_user_id': authUserId,
    ...toJson(),
    'accessible_showroom_ids': accessibleShowroomIds,
    'roles': roles.map((RoleModel role) => role.toJson()).toList(),
    'last_login_at': lastLoginAt?.toIso8601String(),
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  AppUserModel copyWith({
    String? name,
    String? showroomId,
    String? email,
    String? phone,
    UserStatus? status,
    String? avatarUrl,
    String? employeeCode,
    String? designation,
    List<RoleModel>? roles,
    List<String>? accessibleShowroomIds,
    DateTime? lastLoginAt,
  }) => AppUserModel(
    id: id,
    authUserId: authUserId,
    name: name ?? this.name,
    showroomId: showroomId ?? this.showroomId,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    status: status ?? this.status,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    employeeCode: employeeCode ?? this.employeeCode,
    designation: designation ?? this.designation,
    roles: roles ?? this.roles,
    accessibleShowroomIds: accessibleShowroomIds ?? this.accessibleShowroomIds,
    lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    revision: revision,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) => other is AppUserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppUser($name, roles: ${roleNames.join('/')})';
}
