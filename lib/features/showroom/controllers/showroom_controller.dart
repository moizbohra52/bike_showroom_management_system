import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:bike_showroom_management_system/features/showroom/repositories/showroom_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the showroom list. Not scoped to the active showroom — a manager's
/// own branch is only one of possibly several they should be able to browse
/// (and a SUPER ADMIN sees every branch), which is exactly what RLS already
/// resolves; this list is deliberately unfiltered by showroom.
class ShowroomController extends ListController<ShowroomModel> {
  ShowroomController({required ShowroomRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['name', 'code', 'city'],
      );

  @override
  bool get scopeToActiveShowroom => false;

  ShowroomRepository get _repository => repository as ShowroomRepository;

  Future<void> toggleStatus(ShowroomModel showroom) async {
    final RecordStatus next = showroom.isActive
        ? RecordStatus.inactive
        : RecordStatus.active;
    try {
      await _repository.update(showroom.id, <String, Object?>{
        'status': next.value,
      });
      AppSnackbar.success(
        next.isActive ? 'Showroom activated.' : 'Showroom deactivated.',
      );
      await reload();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }
}

/// Owns the create/edit form for a single showroom.
class ShowroomFormController extends GetxController {
  ShowroomFormController({
    required this.showroomRepository,
    ShowroomModel? existing,
  }) : editing = existing;

  final ShowroomRepository showroomRepository;

  /// Null when creating a new showroom.
  final ShowroomModel? editing;

  bool get isEditing => editing != null;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  final TextEditingController panController = TextEditingController();
  final TextEditingController invoicePrefixController = TextEditingController();

  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    final ShowroomModel? source = editing;
    if (source != null) {
      nameController.text = source.name;
      codeController.text = source.code;
      addressController.text = source.address ?? '';
      cityController.text = source.city ?? '';
      stateController.text = source.state ?? '';
      pincodeController.text = source.pincode ?? '';
      phoneController.text = source.phone ?? '';
      emailController.text = source.email ?? '';
      gstController.text = source.gstNumber ?? '';
      panController.text = source.panNumber ?? '';
      invoicePrefixController.text = source.invoicePrefix ?? '';
    }
  }

  String? validateName(String? value) =>
      AppValidators.name(value, field: 'Showroom name');

  String? validateCode(String? value) => AppValidators.code(
    value,
    field: 'Showroom code',
    minLength: 2,
    maxLength: 20,
  );

  String? validatePhone(String? value) => AppValidators.alternatePhone(value);

  String? validateEmail(String? value) =>
      AppValidators.email(value, isRequired: false);

  String? validateGst(String? value) => AppValidators.gstNumber(value);

  String? validatePan(String? value) => AppValidators.panNumber(value);

  String? validatePincode(String? value) => AppValidators.pincode(value);

  /// Returns the saved showroom on success, or null on failure (a toast has
  /// already been shown).
  Future<ShowroomModel?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }

    final String permission = isEditing
        ? AppPermissions.showroomEdit
        : AppPermissions.showroomCreate;
    if (!Get.find<SessionController>().can(permission)) {
      AppSnackbar.error('You do not have permission to do this.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'name': nameController.text.trim(),
        'code': codeController.text.trim().toUpperCase(),
        'address': _orNull(addressController.text),
        'city': _orNull(cityController.text),
        'state': _orNull(stateController.text),
        'pincode': _orNull(pincodeController.text),
        'phone': _orNull(phoneController.text),
        'email': _orNull(emailController.text),
        'gst_number': _orNull(gstController.text)?.toUpperCase(),
        'pan_number': _orNull(panController.text)?.toUpperCase(),
        'invoice_prefix': _orNull(invoicePrefixController.text)?.toUpperCase(),
      };

      final ShowroomModel saved = isEditing
          ? await showroomRepository.update(
              editing!.id,
              payload,
              expectedRevision: editing!.revision,
            )
          : await showroomRepository.create(payload);

      AppSnackbar.success(
        isEditing ? 'Showroom updated.' : 'Showroom created.',
      );
      return saved;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  String? _orNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void onClose() {
    nameController.dispose();
    codeController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    phoneController.dispose();
    emailController.dispose();
    gstController.dispose();
    panController.dispose();
    invoicePrefixController.dispose();
    super.onClose();
  }
}
