import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/features/auth/models/app_user_model.dart';

/// Remote data source for `users`.
///
/// The identity model ([AppUserModel]) lives under `features/auth/models`
/// because it is shared with sign-in and session resolution; this
/// repository is the administrative surface over the same table — listing,
/// deactivating, and assigning roles and showrooms to *other* users, gated
/// by `users.view` / `users.edit` / `users.assign` rather than by "this is
/// me".
class UserRepository extends SupabaseRepository<AppUserModel> {
  UserRepository({super.client});

  @override
  String get table => DbTables.users;

  @override
  String get defaultSortColumn => 'name';

  /// Embeds roles through the join table and every additional showroom
  /// assignment, matching what [AppUserModel.fromJson] parses.
  @override
  String get defaultSelect =>
      '*, user_roles(roles(*)), user_showrooms(showroom_id)';

  @override
  AppUserModel fromJson(Map<String, Object?> json) =>
      AppUserModel.fromJson(json);

  /// Grants [roleId] to [userId]. A no-op (not an error) if already held,
  /// which is what lets the role-picker UI stay simple: it always "sets"
  /// the desired list rather than diffing it against the current one.
  Future<void> addRole(String userId, String roleId) async {
    await client.from(DbTables.userRoles).insert(<String, Object?>{
      'user_id': userId,
      'role_id': roleId,
    });
  }

  Future<void> removeRole(String userId, String roleId) async {
    await client
        .from(DbTables.userRoles)
        .delete()
        .eq('user_id', userId)
        .eq('role_id', roleId);
  }

  Future<void> addShowroom(String userId, String showroomId) async {
    await client.from(DbTables.userShowrooms).insert(<String, Object?>{
      'user_id': userId,
      'showroom_id': showroomId,
    });
  }

  Future<void> removeShowroom(String userId, String showroomId) async {
    await client
        .from(DbTables.userShowrooms)
        .delete()
        .eq('user_id', userId)
        .eq('showroom_id', showroomId);
  }
}
