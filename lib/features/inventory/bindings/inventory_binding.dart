import 'package:bike_showroom_management_system/features/inventory/controllers/inventory_controller.dart';
import 'package:bike_showroom_management_system/features/inventory/controllers/stock_history_controller.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/inventory_repository.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/stock_movement_repository.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:get/get.dart';

class InventoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InventoryRepository>(InventoryRepository.new);
    Get.lazyPut<InventoryController>(
      () => InventoryController(repository: Get.find<InventoryRepository>()),
    );
  }
}

class InventoryFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InventoryRepository>(InventoryRepository.new);
    Get.lazyPut<ProductRepository>(ProductRepository.new);
    Get.lazyPut<InventoryFormController>(
      () => InventoryFormController(
        inventoryRepository: Get.find<InventoryRepository>(),
        productRepository: Get.find<ProductRepository>(),
        existing: Get.arguments as InventoryModel?,
      ),
    );
  }
}

/// Serves both the branch-wide ledger and one unit's timeline. Which one is
/// decided by whether an [InventoryModel] arrives in `Get.arguments`.
class StockHistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StockMovementRepository>(StockMovementRepository.new);
    Get.lazyPut<StockHistoryController>(
      () => StockHistoryController(
        repository: Get.find<StockMovementRepository>(),
        unit: Get.arguments as InventoryModel?,
      ),
    );
  }
}
