import 'package:bike_showroom_management_system/features/customers/controllers/customer_controller.dart';
import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:bike_showroom_management_system/features/customers/repositories/customer_repository.dart';
import 'package:get/get.dart';

class CustomerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerRepository>(CustomerRepository.new);
    Get.lazyPut<CustomerController>(
      () => CustomerController(repository: Get.find<CustomerRepository>()),
    );
  }
}

class CustomerFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomerRepository>(CustomerRepository.new);
    Get.lazyPut<CustomerFormController>(
      () => CustomerFormController(
        customerRepository: Get.find<CustomerRepository>(),
        existing: Get.arguments as CustomerModel?,
      ),
    );
  }
}
