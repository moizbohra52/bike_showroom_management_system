import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_category_model.dart';

/// Remote data source for `expense_categories`.
///
/// Shared across showrooms and with no soft-delete column — a category is
/// retired by clearing `is_active`, because expenses already booked under it
/// must stay resolvable.
class ExpenseCategoryRepository
    extends SupabaseRepository<ExpenseCategoryModel> {
  ExpenseCategoryRepository({super.client});

  @override
  String get table => DbTables.expenseCategories;

  @override
  String get defaultSortColumn => 'name';

  @override
  String? get softDeleteColumn => null;

  @override
  ExpenseCategoryModel fromJson(Map<String, Object?> json) =>
      ExpenseCategoryModel.fromJson(json);

  /// Active categories, for the expense form's picker.
  Future<List<ExpenseCategoryModel>> listActive() => listAll(
    QueryParams(
      pageSize: 200,
      filters: <QueryFilter>[const QueryFilter.equals('is_active', true)],
      sorts: <QuerySort>[
        const QuerySort(column: 'name', direction: SortDirection.ascending),
      ],
    ),
  );
}
