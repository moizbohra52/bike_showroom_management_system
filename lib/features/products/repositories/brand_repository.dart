import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/products/models/brand_model.dart';

/// Remote data source for `brands`.
///
/// Not showroom-scoped: the manufacturer catalogue is shared by every branch,
/// and RLS gates it on the `products` permission module rather than on
/// tenancy.
class BrandRepository extends SupabaseRepository<BrandModel> {
  BrandRepository({super.client});

  @override
  String get table => DbTables.brands;

  @override
  String get defaultSortColumn => 'name';

  @override
  BrandModel fromJson(Map<String, Object?> json) => BrandModel.fromJson(json);

  /// Every active brand, for the product form's brand dropdown.
  ///
  /// Inactive brands are excluded deliberately: a retired manufacturer must
  /// stay resolvable on the products that already reference it, but offering
  /// it for a *new* product would keep the catalogue growing on a line the
  /// business has stopped selling.
  Future<List<BrandModel>> listActive() => listAll(
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
