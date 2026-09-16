import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/products/models/brand_model.dart';
import 'package:bike_showroom_management_system/features/products/repositories/brand_repository.dart';
import 'package:get/get.dart';

/// Drives the brand list.
///
/// Brands are a shared catalogue, so this list is never narrowed to the active
/// showroom — doing so would hide manufacturers that other branches stock and
/// make the same brand look absent depending on who is signed in.
class BrandController extends ListController<BrandModel> {
  BrandController({required BrandRepository repository})
    : super(repository: repository, searchColumns: const <String>['name']);

  @override
  bool get scopeToActiveShowroom => false;

  BrandRepository get _repository => repository as BrandRepository;

  final RxBool isSaving = false.obs;

  /// Creates a brand, or renames [existing] when supplied.
  ///
  /// Returns true on success. The dialog stays open on failure so the typed
  /// name is not lost.
  Future<bool> save({required String name, BrandModel? existing}) async {
    final String permission = existing == null
        ? AppPermissions.productsCreate
        : AppPermissions.productsEdit;
    if (!Get.find<SessionController>().can(permission)) {
      AppSnackbar.error('You do not have permission to do this.');
      return false;
    }

    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      AppSnackbar.error('Enter a brand name.');
      return false;
    }

    isSaving.value = true;
    try {
      if (existing == null) {
        await _repository.create(<String, Object?>{'name': trimmed});
        AppSnackbar.success('Brand added.');
      } else {
        await _repository.update(existing.id, <String, Object?>{
          'name': trimmed,
        }, expectedRevision: existing.revision);
        AppSnackbar.success('Brand updated.');
      }
      await reload();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> toggleStatus(BrandModel brand) async {
    final RecordStatus next = brand.isActive
        ? RecordStatus.inactive
        : RecordStatus.active;
    try {
      await _repository.update(brand.id, <String, Object?>{
        'status': next.value,
      });
      AppSnackbar.success(
        next.isActive ? 'Brand activated.' : 'Brand deactivated.',
      );
      await reload();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }
}
