import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/features/accounting/models/account_model.dart';

/// Remote data source for `accounts` and the `trial_balance` view.
class AccountRepository extends SupabaseRepository<AccountModel> {
  AccountRepository({super.client});

  @override
  String get table => DbTables.accounts;

  /// The chart reads in code order, which is how an accountant expects it.
  @override
  String get defaultSortColumn => 'account_code';

  /// No soft-delete column — an account is deactivated, never removed, because
  /// entries point at it for as long as the books are kept.
  @override
  String? get softDeleteColumn => null;

  @override
  AccountModel fromJson(Map<String, Object?> json) =>
      AccountModel.fromJson(json);

  /// The whole chart for one branch, in code order.
  Future<List<AccountModel>> listChart(String showroomId) => listAll(
    QueryParams(
      pageSize: 300,
      showroomId: showroomId,
      sorts: <QuerySort>[
        const QuerySort(
          column: 'account_code',
          direction: SortDirection.ascending,
        ),
      ],
    ),
  );

  /// The trial balance for one branch.
  ///
  /// Read from the view rather than summed here: the aggregation belongs in
  /// the database, and pulling every entry to add them up client-side would
  /// transfer the entire ledger to produce one page of figures.
  Future<List<TrialBalanceRow>> trialBalance(String showroomId) async {
    try {
      final List<Map<String, Object?>> rows = await client
          .from('trial_balance')
          .select()
          .eq(DbColumns.showroomId, showroomId)
          .order('account_code');
      return rows.map(TrialBalanceRow.fromJson).toList(growable: false);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }
}
