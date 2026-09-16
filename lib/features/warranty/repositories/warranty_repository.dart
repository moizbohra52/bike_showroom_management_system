import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/warranty/models/warranty_model.dart';

/// Remote data source for `warranties`.
class WarrantyRepository extends SupabaseRepository<WarrantyModel> {
  WarrantyRepository({super.client});

  @override
  String get table => DbTables.warranties;

  @override
  String get defaultSortColumn => 'end_date';

  /// No soft-delete column: a warranty is voided or left to expire.
  @override
  String? get softDeleteColumn => null;

  @override
  String get defaultSelect =>
      '*, customer_vehicles(id, registration_number, chassis_number, '
      'customers(id, name, phone))';

  @override
  WarrantyModel fromJson(Map<String, Object?> json) =>
      WarrantyModel.fromJson(json);

  /// Cover lapsing soon — the renewal call list for extended warranties.
  Future<PaginatedResponse<WarrantyModel>> listExpiring(String showroomId) =>
      list(
        QueryParams(
          pageSize: 100,
          showroomId: showroomId,
          filters: <QueryFilter>[
            QueryFilter.inList('status', <String>[
              WarrantyStatus.expiringSoon.value,
              WarrantyStatus.expired.value,
            ]),
          ],
          sorts: <QuerySort>[
            const QuerySort(
              column: 'end_date',
              direction: SortDirection.ascending,
            ),
          ],
        ),
      );

  /// Every warranty on one vehicle — standard plus any extended cover.
  Future<List<WarrantyModel>> listForVehicle(String vehicleId) => listAll(
    QueryParams(
      pageSize: 50,
      filters: <QueryFilter>[QueryFilter.equals('vehicle_id', vehicleId)],
    ),
  );
}

/// Remote data source for `warranty_claims`.
class WarrantyClaimRepository
    extends SupabaseRepository<WarrantyClaimModel> {
  WarrantyClaimRepository({super.client});

  @override
  String get table => DbTables.warrantyClaims;

  @override
  String get defaultSortColumn => 'claim_date';

  @override
  String? get softDeleteColumn => null;

  /// Reaches the vehicle and its owner through the warranty, which is the
  /// only path there is — a claim has no direct vehicle column.
  @override
  String get defaultSelect =>
      '*, warranties(id, warranty_type, '
      'customer_vehicles(id, registration_number, chassis_number, '
      'customers(id, name)))';

  @override
  WarrantyClaimModel fromJson(Map<String, Object?> json) =>
      WarrantyClaimModel.fromJson(json);

  /// Reserves the next claim number for [showroomId].
  Future<String> nextClaimNumber(String showroomId) async {
    final Object? result = await rpc('next_document_number', <String, Object?>{
      'p_showroom_id': showroomId,
      'p_document_type': 'CLAIM',
    });
    return result?.toString() ?? '';
  }
}
