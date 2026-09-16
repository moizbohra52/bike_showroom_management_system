import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/purchases/models/supplier_model.dart';
import 'package:bike_showroom_management_system/features/purchases/repositories/supplier_repository.dart';
import 'package:get/get.dart';

/// Drives the supplier list.
///
/// Not showroom-scoped: suppliers are shared, so narrowing the list would hide
/// a distributor another branch buys from.
class SupplierController extends ListController<SupplierModel> {
  SupplierController({required SupplierRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['name', 'code', 'phone', 'gst_number'],
      );

  @override
  bool get scopeToActiveShowroom => false;

  SupplierRepository get _repository => repository as SupplierRepository;

  final RxBool isSaving = false.obs;

  /// Creates or updates a supplier. Returns true on success; the dialog stays
  /// open on failure so nothing typed is lost.
  Future<bool> save({
    required String name,
    String? code,
    String? phone,
    String? gstNumber,
    String? city,
    SupplierModel? existing,
  }) async {
    final String permission = existing == null
        ? AppPermissions.suppliersCreate
        : AppPermissions.suppliersEdit;
    if (!Get.find<SessionController>().can(permission)) {
      AppSnackbar.error('You do not have permission to do this.');
      return false;
    }
    if (name.trim().isEmpty) {
      AppSnackbar.error('Enter a supplier name.');
      return false;
    }

    // Validated here as well as by the database, so a malformed GSTIN is
    // caught before the round trip rather than as a constraint error.
    final String? gstError = AppValidators.gstNumber(gstNumber);
    if (gstError != null) {
      AppSnackbar.error(gstError);
      return false;
    }

    isSaving.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'name': name.trim(),
        'code': _orNull(code)?.toUpperCase(),
        'phone': _orNull(phone),
        'gst_number': _orNull(gstNumber)?.toUpperCase(),
        'city': _orNull(city),
      };
      if (existing == null) {
        await _repository.create(payload);
        AppSnackbar.success('Supplier added.');
      } else {
        await _repository.update(
          existing.id,
          payload,
          expectedRevision: existing.revision,
        );
        AppSnackbar.success('Supplier updated.');
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

  Future<void> toggleStatus(SupplierModel supplier) async {
    final RecordStatus next = supplier.isActive
        ? RecordStatus.inactive
        : RecordStatus.active;
    try {
      await _repository.update(supplier.id, <String, Object?>{
        'status': next.value,
      });
      await reload();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }

  String? _orNull(String? value) {
    final String trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
