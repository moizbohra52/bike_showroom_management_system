import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:bike_showroom_management_system/features/purchases/controllers/purchase_controller.dart';
import 'package:bike_showroom_management_system/features/purchases/controllers/supplier_controller.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_model.dart';
import 'package:bike_showroom_management_system/features/purchases/repositories/purchase_repository.dart';
import 'package:bike_showroom_management_system/features/purchases/repositories/supplier_repository.dart';
import 'package:get/get.dart';

class SupplierBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SupplierRepository>(SupplierRepository.new);
    Get.lazyPut<SupplierController>(
      () => SupplierController(repository: Get.find<SupplierRepository>()),
    );
  }
}

class PurchaseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PurchaseRepository>(PurchaseRepository.new);
    Get.lazyPut<PurchaseController>(
      () => PurchaseController(repository: Get.find<PurchaseRepository>()),
    );
  }
}

class PurchaseCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PurchaseRepository>(PurchaseRepository.new);
    Get.lazyPut<SupplierRepository>(SupplierRepository.new);
    Get.lazyPut<ProductRepository>(ProductRepository.new);
    Get.lazyPut<PurchaseCreateController>(
      () => PurchaseCreateController(
        purchaseRepository: Get.find<PurchaseRepository>(),
        supplierRepository: Get.find<SupplierRepository>(),
        productRepository: Get.find<ProductRepository>(),
      ),
    );
  }
}

class PurchaseDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PurchaseRepository>(PurchaseRepository.new);
    Get.lazyPut<PurchaseDetailsController>(
      () => PurchaseDetailsController(
        purchaseRepository: Get.find<PurchaseRepository>(),
        purchase: Get.arguments as PurchaseModel,
      ),
    );
  }
}
