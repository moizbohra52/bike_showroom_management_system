import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';

/// Remote data source for `showrooms`.
///
/// Showrooms are the tenancy root: every other repository's query is scoped
/// by `showroom_id`, but this one is not, because RLS scopes it by the
/// row's own `id` instead (see `showrooms_select` in `009_rls.sql`).
class ShowroomRepository extends SupabaseRepository<ShowroomModel> {
  ShowroomRepository({super.client});

  @override
  String get table => DbTables.showrooms;

  @override
  String get defaultSortColumn => 'name';

  @override
  ShowroomModel fromJson(Map<String, Object?> json) =>
      ShowroomModel.fromJson(json);
}
