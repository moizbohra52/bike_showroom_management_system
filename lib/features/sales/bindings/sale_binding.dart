import 'package:bike_showroom_management_system/features/customers/repositories/customer_repository.dart';
import 'package:bike_showroom_management_system/features/finance/repositories/finance_company_repository.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/inventory_repository.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:bike_showroom_management_system/features/sales/controllers/sale_controller.dart';
import 'package:bike_showroom_management_system/features/sales/controllers/sale_create_controller.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_model.dart';
import 'package:bike_showroom_management_system/features/sales/repositories/sale_repository.dart';
import 'package:get/get.dart';

class SaleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SaleRepository>(SaleRepository.new);
    Get.lazyPut<SaleController>(
      () => SaleController(repository: Get.find<SaleRepository>()),
    );
  }
}

/// The create screen pulls from five repositories: a sale needs a customer, a
/// unit from stock, the catalogue price of that unit's product, and — when
/// financed — a financier.
class SaleCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SaleRepository>(SaleRepository.new);
    Get.lazyPut<CustomerRepository>(CustomerRepository.new);
    Get.lazyPut<InventoryRepository>(InventoryRepository.new);
    Get.lazyPut<ProductRepository>(ProductRepository.new);
    Get.lazyPut<FinanceCompanyRepository>(FinanceCompanyRepository.new);
    Get.lazyPut<SaleCreateController>(
      () => SaleCreateController(
        saleRepository: Get.find<SaleRepository>(),
        customerRepository: Get.find<CustomerRepository>(),
        inventoryRepository: Get.find<InventoryRepository>(),
        productRepository: Get.find<ProductRepository>(),
        financeCompanyRepository: Get.find<FinanceCompanyRepository>(),
      ),
    );
  }
}

class SaleDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SaleRepository>(SaleRepository.new);
    Get.lazyPut<SaleDetailsController>(
      () => SaleDetailsController(
        saleRepository: Get.find<SaleRepository>(),
        sale: Get.arguments as SaleModel,
      ),
    );
  }
}
