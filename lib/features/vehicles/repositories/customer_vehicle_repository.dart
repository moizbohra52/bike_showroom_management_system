import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';

/// Remote data source for `customer_vehicles`.
class CustomerVehicleRepository
    extends SupabaseRepository<CustomerVehicleModel> {
  CustomerVehicleRepository({super.client});

  @override
  String get table => DbTables.customerVehicles;

  @override
  String get defaultSortColumn => DbColumns.createdAt;

  @override
  String get defaultSelect =>
      '*, customers(id, name, phone), '
      'products(id, name, model, variant, brands(id, name))';

  @override
  CustomerVehicleModel fromJson(Map<String, Object?> json) =>
      CustomerVehicleModel.fromJson(json);

  /// Every vehicle belonging to one customer.
  Future<List<CustomerVehicleModel>> listForCustomer(String customerId) =>
      listAll(
        QueryParams(
          pageSize: 100,
          filters: <QueryFilter>[QueryFilter.equals('customer_id', customerId)],
        ),
      );
}
