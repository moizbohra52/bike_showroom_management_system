import 'package:bike_showroom_management_system/features/roles/controllers/role_controller.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';
import 'package:bike_showroom_management_system/features/roles/repositories/role_repository.dart';
import 'package:get/get.dart';

class RoleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RoleRepository>(RoleRepository.new);
    Get.lazyPut<RoleController>(
      () => RoleController(repository: Get.find<RoleRepository>()),
    );
  }
}

class RoleFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RoleRepository>(RoleRepository.new);
    Get.lazyPut<RoleFormController>(
      () => RoleFormController(
        roleRepository: Get.find<RoleRepository>(),
        existing: Get.arguments as RoleModel?,
      ),
    );
  }
}

class RolePermissionsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RoleRepository>(RoleRepository.new);
    Get.lazyPut<PermissionRepository>(PermissionRepository.new);
    Get.lazyPut<RolePermissionsController>(
      () => RolePermissionsController(
        roleRepository: Get.find<RoleRepository>(),
        permissionRepository: Get.find<PermissionRepository>(),
        role: Get.arguments as RoleModel,
      ),
    );
  }
}
