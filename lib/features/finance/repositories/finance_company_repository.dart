import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/finance/models/finance_company_model.dart';

/// Remote data source for `finance_companies`. Not showroom-scoped; see
/// [FinanceCompanyModel].
class FinanceCompanyRepository extends SupabaseRepository<FinanceCompanyModel> {
  FinanceCompanyRepository({super.client});

  @override
  String get table => DbTables.financeCompanies;

  @override
  String get defaultSortColumn => 'name';

  @override
  FinanceCompanyModel fromJson(Map<String, Object?> json) =>
      FinanceCompanyModel.fromJson(json);

  /// Active financiers, for the loan form's picker.
  Future<List<FinanceCompanyModel>> listActive() => listAll(
    QueryParams(
      pageSize: 100,
      filters: <QueryFilter>[
        QueryFilter.equals('status', RecordStatus.active.value),
      ],
      sorts: <QuerySort>[
        const QuerySort(column: 'name', direction: SortDirection.ascending),
      ],
    ),
  );
}
