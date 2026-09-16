import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/roles/models/permission_model.dart';

/// A row from `roles`, optionally with its permissions embedded.
class RoleModel {
  const RoleModel({
    required this.id,
    required this.name,
    this.description,
    this.isSystemRole = false,
    this.permissions = const <PermissionModel>[],
    this.userCount,
    this.createdAt,
    this.updatedAt,
  });

  /// Parses a role, tolerating either shape PostgREST can return for the
  /// nested permissions: a direct join on `permissions`, or a nested one
  /// through the `role_permissions` join table.
  factory RoleModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);

    List<PermissionModel> parsePermissions() {
      // Direct embed: `select=*,permissions(*)`
      final List<Map<String, Object?>> direct = reader.objectList(
        'permissions',
      );
      if (direct.isNotEmpty) {
        return direct.map(PermissionModel.fromJson).toList(growable: false);
      }
      // Through the join table: `select=*,role_permissions(permissions(*))`
      final List<Map<String, Object?>> viaJoin = reader.objectList(
        'role_permissions',
      );
      if (viaJoin.isNotEmpty) {
        final List<PermissionModel> result = <PermissionModel>[];
        for (final Map<String, Object?> link in viaJoin) {
          final Map<String, Object?>? permission = JsonReader(
            link,
          ).objectOrNull('permissions');
          if (permission != null) {
            result.add(PermissionModel.fromJson(permission));
          }
        }
        return result;
      }
      return const <PermissionModel>[];
    }

    return RoleModel(
      id: reader.requireString('id'),
      name: reader.string('name'),
      description: reader.stringOrNull('description'),
      isSystemRole: reader.boolean('is_system_role'),
      permissions: parsePermissions(),
      userCount: reader.intOrNull('user_count'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  final String id;

  /// Matches `AppRole.value` for the seeded roles.
  final String name;

  final String? description;

  /// System roles are seeded and cannot be renamed or deleted, because
  /// `is_super_admin()` and the RLS policies resolve them by name.
  final bool isSystemRole;

  final List<PermissionModel> permissions;

  /// Populated by the role list query's aggregate count, so the UI can warn
  /// before removing a role that is still assigned.
  final int? userCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The strongly-typed role, when this is one of the seeded roles.
  AppRole? get appRole => AppRole.fromValue(name);

  bool get isSuperAdmin => name == AppRole.superAdmin.value;

  /// Display label, preferring the enum's friendly casing.
  String get label => appRole?.label ?? name;

  /// Lower is broader authority; unknown custom roles sort last.
  int get rank => appRole?.rank ?? 100;

  Set<String> get permissionKeys =>
      permissions.map((PermissionModel p) => p.key).toSet();

  PermissionSet get permissionSet =>
      isSuperAdmin ? PermissionSet.superAdmin() : PermissionSet(permissionKeys);

  bool get canBeDeleted => !isSystemRole && (userCount ?? 0) == 0;

  /// Write payload. `is_system_role` is deliberately omitted: it is set only
  /// by the seed migration, and letting a client flip it would allow a custom
  /// role to impersonate a protected one.
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'name': name.trim(),
    'description': description,
  });

  RoleModel copyWith({
    String? id,
    String? name,
    String? description,
    bool? isSystemRole,
    List<PermissionModel>? permissions,
    int? userCount,
  }) => RoleModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    isSystemRole: isSystemRole ?? this.isSystemRole,
    permissions: permissions ?? this.permissions,
    userCount: userCount ?? this.userCount,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) => other is RoleModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Role($name, ${permissions.length} permissions)';
}
