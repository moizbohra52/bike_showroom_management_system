import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/insurance/models/insurance_policy_model.dart';

/// Remote data source for `insurance_policies`.
class InsuranceRepository extends SupabaseRepository<InsurancePolicyModel> {
  InsuranceRepository({super.client});

  @override
  String get table => DbTables.insurancePolicies;

  /// Ordered by expiry: the renewal desk works from whichever lapses first.
  @override
  String get defaultSortColumn => 'expiry_date';

  /// No soft-delete column: a policy is cancelled or left to expire.
  @override
  String? get softDeleteColumn => null;

  @override
  String get defaultSelect =>
      '*, customer_vehicles(id, registration_number, chassis_number, '
      'customers(id, name, phone))';

  @override
  InsurancePolicyModel fromJson(Map<String, Object?> json) =>
      InsurancePolicyModel.fromJson(json);

  /// Policies that have lapsed or are about to — the renewal call list.
  Future<PaginatedResponse<InsurancePolicyModel>> listForRenewal(
    String showroomId,
  ) => list(
    QueryParams(
      pageSize: 100,
      showroomId: showroomId,
      filters: <QueryFilter>[
        QueryFilter.inList('status', <String>[
          InsuranceStatus.expiringSoon.value,
          InsuranceStatus.expired.value,
        ]),
      ],
      sorts: <QuerySort>[
        const QuerySort(
          column: 'expiry_date',
          direction: SortDirection.ascending,
        ),
      ],
    ),
  );
}
