import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/features/service/models/service_item_model.dart';
import 'package:bike_showroom_management_system/features/service/models/service_record_model.dart';

/// Remote data source for `service_records` and their lines.
///
/// Booking a job card is an ordinary insert — it commits nothing financially,
/// so there is nothing to make atomic. Completion is an RPC, because that is
/// where the money appears.
class ServiceRepository extends SupabaseRepository<ServiceRecordModel> {
  ServiceRepository({super.client});

  @override
  String get table => DbTables.serviceRecords;

  @override
  String get defaultSortColumn => 'service_date';

  /// No `is_deleted` column: a job card is cancelled, never deleted (§42).
  @override
  String? get softDeleteColumn => null;

  /// The advisor embed **must** name its foreign key. `service_records`
  /// references `users` four times — advisor, technician, created_by,
  /// updated_by — so a bare `users(...)` is ambiguous and PostgREST rejects
  /// the request with PGRST201.
  @override
  String get defaultSelect =>
      '*, customers(id, name, phone), '
      'customer_vehicles(id, registration_number, chassis_number), '
      'users!service_records_service_advisor_id_fkey(id, name)';

  String get detailSelect =>
      '$defaultSelect, service_items(*, products(id, name))';

  @override
  ServiceRecordModel fromJson(Map<String, Object?> json) =>
      ServiceRecordModel.fromJson(json);

  Future<ServiceRecordModel> getDetail(String id) =>
      getById(id, select: detailSelect);

  /// Reserves the next job-card number for [showroomId].
  Future<String> nextServiceNumber(String showroomId) async {
    final Object? result = await rpc('next_document_number', <String, Object?>{
      'p_showroom_id': showroomId,
      'p_document_type': 'SERVICE',
    });
    return result?.toString() ?? '';
  }

  /// Open job cards — what a workshop board shows.
  Future<PaginatedResponse<ServiceRecordModel>> listOpen(String showroomId) =>
      list(
        QueryParams(
          pageSize: 100,
          showroomId: showroomId,
          filters: <QueryFilter>[
            QueryFilter.inList('service_status', <String>[
              ServiceStatus.booked.value,
              ServiceStatus.received.value,
              ServiceStatus.inProgress.value,
              ServiceStatus.waitingForParts.value,
            ]),
          ],
          sorts: <QuerySort>[
            const QuerySort(
              column: 'service_date',
              direction: SortDirection.ascending,
            ),
          ],
        ),
      );

  // ----------------------------------------------------------------- lines

  Future<ServiceItemModel> addItem(Map<String, Object?> payload) async {
    try {
      final Map<String, Object?> row = await client
          .from(DbTables.serviceItems)
          .insert(payload)
          .select('*, products(id, name)')
          .single();
      return ServiceItemModel.fromJson(row);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Removes a line from a job card that has not been completed.
  ///
  /// A hard delete is right here: until completion the job card is a working
  /// document with no financial effect, so a mistyped line should leave no
  /// trace. After completion the invoice and the ledger reference these
  /// figures, and `complete_service` has already read them.
  Future<void> removeItem(String itemId) async {
    try {
      await client.from(DbTables.serviceItems).delete().eq('id', itemId);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  // ------------------------------------------------------------ completion

  /// Asks whether this vehicle still has a free service due.
  ///
  /// Returns the function's own answer — `eligible`, a `reason` when not, and
  /// the entitlement's id when it is. Checked before offering a FREE service
  /// type so the user is told now rather than at completion.
  Future<Map<String, Object?>> checkFreeServiceEligibility({
    required String vehicleId,
    int? odometer,
  }) async {
    final Object? result = await rpc(
      'check_free_service_eligibility',
      <String, Object?>{
        'p_vehicle_id': vehicleId,
        'p_odometer': odometer,
      },
    );
    if (result is Map) {
      return Map<String, Object?>.from(result);
    }
    return <String, Object?>{'eligible': false, 'reason': 'Unknown'};
  }

  /// Completes a job card through `complete_service`.
  ///
  /// The function totals only the chargeable lines, consumes a free-service
  /// entitlement when the visit qualifies, raises the invoice, posts the
  /// revenue and schedules the next visit — atomically. Setting the status to
  /// COMPLETED directly would leave a finished job with no invoice and no
  /// revenue recorded.
  Future<ServiceCompletionResult> complete({
    required String serviceId,
    double additionalDiscount = 0,
    String? workDone,
  }) async {
    final Object? result = await rpc('complete_service', <String, Object?>{
      'p_payload': <String, Object?>{
        'service_id': serviceId,
        'additional_discount': additionalDiscount,
        if (workDone != null && workDone.trim().isNotEmpty)
          'work_done': workDone.trim(),
      },
    });
    if (result is! Map) {
      throw ServerException(
        message: 'The job card was not completed. Please try again.',
      );
    }
    return ServiceCompletionResult.fromJson(Map<String, Object?>.from(result));
  }
}
