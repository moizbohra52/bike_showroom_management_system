import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:bike_showroom_management_system/features/customers/repositories/customer_repository.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:bike_showroom_management_system/features/vehicles/controllers/vehicle_controller.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';
import 'package:bike_showroom_management_system/features/vehicles/repositories/customer_vehicle_repository.dart';
import 'package:get/get.dart';

/// Serves both the branch-wide vehicle list and one customer's garage,
/// depending on whether a [CustomerModel] arrives in `Get.arguments`.
class VehicleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerVehicleRepository>(CustomerVehicleRepository.new);
    Get.lazyPut<VehicleController>(
      () => VehicleController(
        repository: Get.find<CustomerVehicleRepository>(),
        customer: Get.arguments is CustomerModel
            ? Get.arguments as CustomerModel
            : null,
      ),
    );
  }
}

/// The form route takes either the vehicle being edited or, when adding from
/// a customer's garage, the customer to pre-select as its owner. Both arrive
/// through the same `Get.arguments`, so the type decides which it is.
class VehicleFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerVehicleRepository>(CustomerVehicleRepository.new);
    Get.lazyPut<CustomerRepository>(CustomerRepository.new);
    Get.lazyPut<ProductRepository>(ProductRepository.new);

    final Object? argument = Get.arguments;
    Get.lazyPut<VehicleFormController>(
      () => VehicleFormController(
        vehicleRepository: Get.find<CustomerVehicleRepository>(),
        customerRepository: Get.find<CustomerRepository>(),
        productRepository: Get.find<ProductRepository>(),
        existing: argument is CustomerVehicleModel ? argument : null,
        presetCustomer: argument is CustomerModel ? argument : null,
      ),
    );
  }
}
