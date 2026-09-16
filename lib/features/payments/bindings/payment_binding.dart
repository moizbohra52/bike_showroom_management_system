import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';
import 'package:bike_showroom_management_system/features/billing/repositories/invoice_repository.dart';
import 'package:bike_showroom_management_system/features/payments/controllers/payment_controller.dart';
import 'package:bike_showroom_management_system/features/payments/repositories/payment_repository.dart';
import 'package:get/get.dart';

class PaymentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaymentRepository>(PaymentRepository.new);
    Get.lazyPut<PaymentController>(
      () => PaymentController(repository: Get.find<PaymentRepository>()),
    );
  }
}

/// The form takes an optional [InvoiceModel] through `Get.arguments` when it
/// is opened from an invoice, so that invoice is pre-selected.
class PaymentFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaymentRepository>(PaymentRepository.new);
    Get.lazyPut<InvoiceRepository>(InvoiceRepository.new);
    Get.lazyPut<PaymentFormController>(
      () => PaymentFormController(
        paymentRepository: Get.find<PaymentRepository>(),
        invoiceRepository: Get.find<InvoiceRepository>(),
        presetInvoice: Get.arguments is InvoiceModel
            ? Get.arguments as InvoiceModel
            : null,
      ),
    );
  }
}
