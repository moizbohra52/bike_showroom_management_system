import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:bike_showroom_management_system/features/customers/repositories/customer_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the customer list for the active showroom.
class CustomerController extends ListController<CustomerModel> {
  CustomerController({required CustomerRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>[
          'name',
          'phone',
          'customer_code',
          'email',
        ],
      );

  CustomerRepository get _repository => repository as CustomerRepository;

  final Rxn<CustomerType> typeFilter = Rxn<CustomerType>();

  void filterByType(CustomerType? type) {
    typeFilter.value = type;
    if (type == null) {
      removeFilter('customer_type');
    } else {
      applyFilter(QueryFilter.equals('customer_type', type.value));
    }
  }

  Future<void> toggleStatus(CustomerModel customer) async {
    final RecordStatus next = customer.isActive
        ? RecordStatus.inactive
        : RecordStatus.active;
    try {
      await _repository.update(customer.id, <String, Object?>{
        'status': next.value,
      });
      AppSnackbar.success(
        next.isActive ? 'Customer activated.' : 'Customer deactivated.',
      );
      await reload();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }
}

/// Owns the create/edit form for one customer.
class CustomerFormController extends GetxController {
  CustomerFormController({
    required this.customerRepository,
    CustomerModel? existing,
  }) : editing = existing;

  final CustomerRepository customerRepository;

  final CustomerModel? editing;

  bool get isEditing => editing != null;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController alternatePhoneController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  final TextEditingController panController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  final Rxn<DateTime> dateOfBirth = Rxn<DateTime>();
  final Rx<CustomerType> customerType = CustomerType.individual.obs;
  final Rx<RecordStatus> status = RecordStatus.active.obs;

  final RxBool isSubmitting = false.obs;

  /// Set when the typed phone number already belongs to someone at this
  /// branch, so the form can offer to open that record instead of creating a
  /// second one.
  final Rxn<CustomerModel> duplicate = Rxn<CustomerModel>();

  @override
  void onInit() {
    super.onInit();
    final CustomerModel? source = editing;
    if (source != null) {
      nameController.text = source.name;
      phoneController.text = source.phone;
      alternatePhoneController.text = source.alternatePhone ?? '';
      emailController.text = source.email ?? '';
      addressController.text = source.address ?? '';
      cityController.text = source.city ?? '';
      stateController.text = source.state ?? '';
      pincodeController.text = source.pincode ?? '';
      gstController.text = source.gstNumber ?? '';
      panController.text = source.panNumber ?? '';
      notesController.text = source.notes ?? '';
      dateOfBirth.value = source.dateOfBirth;
      customerType.value = source.customerType;
      status.value = source.status;
    }
  }

  // ------------------------------------------------------------ validation

  String? validateName(String? value) =>
      AppValidators.name(value, field: 'Customer name');

  String? validatePhone(String? value) => AppValidators.phone(value);

  String? validateAlternatePhone(String? value) =>
      AppValidators.alternatePhone(value);

  String? validateEmail(String? value) =>
      AppValidators.email(value, isRequired: false);

  String? validatePincode(String? value) => AppValidators.pincode(value);

  String? validatePan(String? value) => AppValidators.panNumber(value);

  /// A corporate, dealer or government buyer needs a GST number for the
  /// invoice to be valid; an individual does not.
  String? validateGst(String? value) => AppValidators.gstNumber(
    value,
    isRequired: customerType.value != CustomerType.individual,
  );

  // ------------------------------------------------------- duplicate check

  /// Looks for an existing customer with this phone number.
  ///
  /// Advisory only — the database has a unique index per showroom and would
  /// reject a genuine duplicate anyway. The point is to say so *before* the
  /// user fills in the rest of the form.
  Future<void> checkForDuplicate() async {
    duplicate.value = null;
    if (isEditing) {
      return;
    }
    final String phone = phoneController.text.trim();
    if (AppValidators.phone(phone) != null) {
      return;
    }
    final String? showroomId =
        Get.find<SessionController>().activeShowroomId.value;
    if (showroomId == null) {
      return;
    }
    try {
      duplicate.value = await customerRepository.findByPhone(
        showroomId: showroomId,
        phone: phone,
      );
    } on Object {
      // A failed lookup must not block data entry; the unique index still
      // protects the data.
      duplicate.value = null;
    }
  }

  // ----------------------------------------------------------------- submit

  Future<CustomerModel?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }

    final SessionController session = Get.find<SessionController>();
    final String permission = isEditing
        ? AppPermissions.customersEdit
        : AppPermissions.customersCreate;
    if (!session.can(permission)) {
      AppSnackbar.error('You do not have permission to do this.');
      return null;
    }

    final String? showroomId =
        editing?.showroomId ?? session.activeShowroomId.value;
    if (showroomId == null) {
      AppSnackbar.error('Select a showroom before adding a customer.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'alternate_phone': _orNull(alternatePhoneController.text),
        'email': _orNull(emailController.text)?.toLowerCase(),
        'address': _orNull(addressController.text),
        'city': _orNull(cityController.text),
        'state': _orNull(stateController.text),
        'pincode': _orNull(pincodeController.text),
        'date_of_birth': DateUtil.toIsoDateOrNull(dateOfBirth.value),
        'gst_number': _orNull(gstController.text)?.toUpperCase(),
        'pan_number': _orNull(panController.text)?.toUpperCase(),
        'customer_type': customerType.value.value,
        'notes': _orNull(notesController.text),
        'status': status.value.value,
      };

      if (isEditing) {
        final CustomerModel saved = await customerRepository.update(
          editing!.id,
          payload,
          expectedRevision: editing!.revision,
        );
        AppSnackbar.success('Customer updated.');
        return saved;
      }

      final CustomerModel saved = await customerRepository
          .create(<String, Object?>{
            ...payload,
            'showroom_id': showroomId,
            'customer_code': await customerRepository.nextCustomerCode(
              showroomId,
            ),
          });
      AppSnackbar.success('Customer ${saved.customerCode} created.');
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
    phoneController.dispose();
    alternatePhoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    gstController.dispose();
    panController.dispose();
    notesController.dispose();
    super.onClose();
  }
}
