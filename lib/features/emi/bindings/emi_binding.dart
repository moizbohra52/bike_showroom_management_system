import 'package:bike_showroom_management_system/features/emi/controllers/emi_controller.dart';
import 'package:bike_showroom_management_system/features/emi/repositories/emi_repository.dart';
import 'package:bike_showroom_management_system/features/payments/repositories/payment_repository.dart';
import 'package:get/get.dart';

/// The collections desk both reads instalments and records money against
/// them, and those are two different tables behind two different RPCs.
class EmiBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EmiRepository>(EmiRepository.new);
    Get.lazyPut<PaymentRepository>(PaymentRepository.new);
    Get.lazyPut<EmiController>(
      () => EmiController(
        repository: Get.find<EmiRepository>(),
        paymentRepository: Get.find<PaymentRepository>(),
      ),
    );
  }
}
