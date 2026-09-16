import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/purchases/models/supplier_model.dart';

/// Remote data source for `suppliers`. Not showroom-scoped; see
/// [SupplierModel].
class SupplierRepository extends SupabaseRepository<SupplierModel> {
  SupplierRepository({super.client});

  @override
  String get table => DbTables.suppliers;

  @override
  String get defaultSortColumn => 'name';

  @override
  SupplierModel fromJson(Map<String, Object?> json) =>
      SupplierModel.fromJson(json);

  /// Active suppliers, for the purchase form's picker.
  Future<List<SupplierModel>> listActive() => listAll(
    QueryParams(
      pageSize: 200,
      filters: <QueryFilter>[
        QueryFilter.equals('status', RecordStatus.active.value),
      ],
      sorts: <QuerySort>[
        const QuerySort(column: 'name', direction: SortDirection.ascending),
      ],
    ),
  );
}
