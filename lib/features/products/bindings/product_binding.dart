import 'package:bike_showroom_management_system/features/products/controllers/brand_controller.dart';
import 'package:bike_showroom_management_system/features/products/controllers/product_controller.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/products/repositories/brand_repository.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:get/get.dart';

class ProductBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProductRepository>(ProductRepository.new);
    Get.lazyPut<ProductController>(
      () => ProductController(repository: Get.find<ProductRepository>()),
    );
  }
}

/// Bound to the create/edit route. The product being edited arrives through
/// `Get.arguments`, since the router instantiates a [Bindings] with no way to
/// pass call-site data.
class ProductFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProductRepository>(ProductRepository.new);
    Get.lazyPut<BrandRepository>(BrandRepository.new);
    Get.lazyPut<ProductFormController>(
      () => ProductFormController(
        productRepository: Get.find<ProductRepository>(),
        brandRepository: Get.find<BrandRepository>(),
        existing: Get.arguments as ProductModel?,
      ),
    );
  }
}

class BrandBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BrandRepository>(BrandRepository.new);
    Get.lazyPut<BrandController>(
      () => BrandController(repository: Get.find<BrandRepository>()),
    );
  }
}
