import 'package:bike_showroom_management_system/features/auth/models/app_user_model.dart';
import 'package:bike_showroom_management_system/features/roles/repositories/role_repository.dart';
import 'package:bike_showroom_management_system/features/showroom/repositories/showroom_repository.dart';
import 'package:bike_showroom_management_system/features/users/controllers/user_assignment_controller.dart';
import 'package:bike_showroom_management_system/features/users/controllers/user_controller.dart';
import 'package:bike_showroom_management_system/features/users/controllers/user_invite_controller.dart';
import 'package:bike_showroom_management_system/features/users/repositories/user_repository.dart';
import 'package:get/get.dart';

class UserBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserRepository>(UserRepository.new);
    Get.lazyPut<UserController>(
      () => UserController(repository: Get.find<UserRepository>()),
    );
  }
}

class UserFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserRepository>(UserRepository.new);
    Get.lazyPut<UserFormController>(
      () => UserFormController(
        userRepository: Get.find<UserRepository>(),
        user: Get.arguments as AppUserModel,
      ),
    );
  }
}

class UserAssignmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserRepository>(UserRepository.new);
    Get.lazyPut<RoleRepository>(RoleRepository.new);
    Get.lazyPut<ShowroomRepository>(ShowroomRepository.new);
    Get.lazyPut<UserAssignmentController>(
      () => UserAssignmentController(
        userRepository: Get.find<UserRepository>(),
        roleRepository: Get.find<RoleRepository>(),
        showroomRepository: Get.find<ShowroomRepository>(),
        user: Get.arguments as AppUserModel,
      ),
    );
  }
}

class UserInviteBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RoleRepository>(RoleRepository.new);
    Get.lazyPut<ShowroomRepository>(ShowroomRepository.new);
    Get.lazyPut<UserInviteController>(
      () => UserInviteController(
        roleRepository: Get.find<RoleRepository>(),
        showroomRepository: Get.find<ShowroomRepository>(),
      ),
    );
  }
}
