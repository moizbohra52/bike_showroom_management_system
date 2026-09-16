import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/features/roles/models/permission_model.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';

/// Remote data source for `roles`.
///
/// `roles` carries neither `is_deleted` nor `revision`: a role is either
/// system-seeded (immutable, protected by the RLS policy in `009_rls.sql`)
/// or a small custom set an administrator manages directly, so soft-delete
/// history and optimistic-concurrency tracking are not needed for it.
class RoleRepository extends SupabaseRepository<RoleModel> {
  RoleRepository({super.client});

  @override
  String get table => DbTables.roles;

  @override
  String? get softDeleteColumn => null;

  @override
  String get defaultSortColumn => 'name';

  /// Embeds each role's granted permissions through the join table, which is
  /// what [RoleModel.fromJson] expects.
  @override
  String get defaultSelect => '*, role_permissions(permissions(*))';

  @override
  RoleModel fromJson(Map<String, Object?> json) => RoleModel.fromJson(json);

  /// Atomically replaces [roleId]'s whole permission set. Never issued as a
  /// client-side delete-then-insert: see `set_role_permissions()` in
  /// `016_role_permission_management.sql` for why that would risk leaving the
  /// role with zero permissions if the second step failed.
  Future<int> setPermissions(String roleId, Set<String> permissionIds) async {
    final Object? result = await rpc('set_role_permissions', <String, Object?>{
      'p_role_id': roleId,
      'p_permission_ids': permissionIds.toList(growable: false),
    });
    return result is int ? result : 0;
  }
}

/// Read-only access to the permission catalogue.
///
/// The catalogue is seeded by migration and mirrored in
/// [AppPermissions.all]; it is never written at runtime, which is why this
/// repository exposes no create/update/delete.
class PermissionRepository extends SupabaseRepository<PermissionModel> {
  PermissionRepository({super.client});

  @override
  String get table => DbTables.permissions;

  @override
  String? get softDeleteColumn => null;

  @override
  String get defaultSortColumn => 'module';

  @override
  PermissionModel fromJson(Map<String, Object?> json) =>
      PermissionModel.fromJson(json);

  /// Every permission, unpaginated — the matrix editor needs the whole
  /// catalogue at once, not a page of it.
  Future<List<PermissionModel>> listCatalogue() =>
      listAll(QueryParams(pageSize: 500));
}
