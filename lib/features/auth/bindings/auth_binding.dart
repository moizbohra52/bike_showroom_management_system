import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/features/auth/controllers/auth_controller.dart';
import 'package:bike_showroom_management_system/features/auth/controllers/splash_controller.dart';
import 'package:bike_showroom_management_system/services/auth_service.dart';
import 'package:bike_showroom_management_system/services/storage_service.dart';
import 'package:get/get.dart';

/// Registers the controllers for the authentication screens.
///
/// Dependencies are passed explicitly rather than resolved inside the
/// controllers, which keeps the controllers constructible in a test without
/// a populated GetX container.
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // `fenix` so the controller is rebuilt if it was disposed while the user
    // moved between login, forgot-password and reset screens.
    Get.lazyPut<AuthController>(
      () => AuthController(
        authService: Get.find<AuthService>(),
        sessionController: Get.find<SessionController>(),
        storageService: Get.find<StorageService>(),
      ),
      fenix: true,
    );
  }
}

/// Registers the splash controller, which owns the bootstrap sequence.
class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SplashController>(
      () => SplashController(
        authService: Get.find<AuthService>(),
        sessionController: Get.find<SessionController>(),
      ),
    );
    // The blocked-account and splash screens both offer a sign-out, so the
    // auth controller must be available from here too.
    Get.lazyPut<AuthController>(
      () => AuthController(
        authService: Get.find<AuthService>(),
        sessionController: Get.find<SessionController>(),
        storageService: Get.find<StorageService>(),
      ),
      fenix: true,
    );
  }
}
