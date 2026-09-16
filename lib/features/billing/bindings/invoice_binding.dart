import 'package:bike_showroom_management_system/features/billing/controllers/invoice_controller.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';
import 'package:bike_showroom_management_system/features/billing/repositories/invoice_repository.dart';
import 'package:get/get.dart';

class InvoiceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InvoiceRepository>(InvoiceRepository.new);
    Get.lazyPut<InvoiceController>(
      () => InvoiceController(repository: Get.find<InvoiceRepository>()),
    );
  }
}

class InvoiceDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InvoiceRepository>(InvoiceRepository.new);
    Get.lazyPut<InvoiceDetailsController>(
      () => InvoiceDetailsController(
        invoiceRepository: Get.find<InvoiceRepository>(),
        invoice: Get.arguments as InvoiceModel,
      ),
    );
  }
}
