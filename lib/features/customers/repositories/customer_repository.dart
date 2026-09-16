import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';

/// Remote data source for `customers`.
class CustomerRepository extends SupabaseRepository<CustomerModel> {
  CustomerRepository({super.client});

  @override
  String get table => DbTables.customers;

  @override
  String get defaultSortColumn => 'name';

  /// Asks PostgREST for a vehicle *count* rather than the vehicle rows: the
  /// list only shows "3 vehicles", and fetching the rows to length them would
  /// multiply the payload for a number.
  @override
  String get defaultSelect => '*, customer_vehicles(count)';

  @override
  CustomerModel fromJson(Map<String, Object?> json) =>
      CustomerModel.fromJson(json);

  /// Reserves the next customer number for [showroomId].
  Future<String> nextCustomerCode(String showroomId) async {
    final Object? result = await rpc('next_document_number', <String, Object?>{
      'p_showroom_id': showroomId,
      'p_document_type': 'CUSTOMER',
    });
    return result?.toString() ?? '';
  }

  /// Finds an existing customer by phone within [showroomId].
  ///
  /// Used before creating one: a showroom's staff type the same regular
  /// customer in again and again, and a duplicate splits their vehicles and
  /// service history across two records that no report will ever rejoin.
  Future<CustomerModel?> findByPhone({
    required String showroomId,
    required String phone,
  }) async {
    final PaginatedResponse<CustomerModel> response = await list(
      QueryParams(
        pageSize: 1,
        showroomId: showroomId,
        filters: <QueryFilter>[QueryFilter.equals('phone', phone.trim())],
      ),
    );
    return response.items.isEmpty ? null : response.items.first;
  }

  /// Active customers for a picker (a sale, a service booking).
  Future<List<CustomerModel>> listSelectable(String showroomId) => listAll(
    QueryParams(
      pageSize: 200,
      showroomId: showroomId,
      filters: <QueryFilter>[
        QueryFilter.equals('status', RecordStatus.active.value),
      ],
      sorts: <QuerySort>[
        const QuerySort(column: 'name', direction: SortDirection.ascending),
      ],
    ),
    // The picker shows a name and a phone number; the vehicle-count embed
    // would make the server aggregate a child table for every row of it.
    select: '*',
  );
}
