import 'package:bike_showroom_management_system/features/showroom/controllers/showroom_controller.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:bike_showroom_management_system/features/showroom/repositories/showroom_repository.dart';
import 'package:get/get.dart';

class ShowroomBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShowroomRepository>(ShowroomRepository.new);
    Get.lazyPut<ShowroomController>(
      () => ShowroomController(repository: Get.find<ShowroomRepository>()),
    );
  }
}

/// Bound to the create/edit route. [existing] arrives through `Get.arguments`
/// rather than a constructor argument here, since `Bindings` is instantiated
/// by the router with no way to pass call-site data directly.
class ShowroomFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShowroomRepository>(ShowroomRepository.new);
    Get.lazyPut<ShowroomFormController>(
      () => ShowroomFormController(
        showroomRepository: Get.find<ShowroomRepository>(),
        existing: Get.arguments as ShowroomModel?,
      ),
    );
  }
}
