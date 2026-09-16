import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/insurance/models/insurance_policy_model.dart';
import 'package:bike_showroom_management_system/features/insurance/repositories/insurance_repository.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';
import 'package:bike_showroom_management_system/features/vehicles/repositories/customer_vehicle_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the insurance list for the active showroom.
class InsuranceController extends ListController<InsurancePolicyModel> {
  InsuranceController({required InsuranceRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['policy_number', 'insurance_company'],
      );

  final Rxn<InsuranceStatus> statusFilter = Rxn<InsuranceStatus>();

  void filterByStatus(InsuranceStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter(DbColumns.status);
    } else {
      applyFilter(QueryFilter.equals(DbColumns.status, status.value));
    }
  }

  /// Policies that have lapsed or are about to.
  ///
  /// This is the list the renewal desk actually works from: a lapsed policy
  /// is the most common reason a showroom telephones a customer.
  void showRenewalList() {
    statusFilter.value = null;
    params.value = params.value
        .withFilter(
          QueryFilter.inList('status', <String>[
            InsuranceStatus.expiringSoon.value,
            InsuranceStatus.expired.value,
          ]),
        )
        .resetPage();
    reload();
  }

  void filterByExpiry(DateRange? range) =>
      setDateRange(range, dateColumn: 'expiry_date');
}

/// Records or renews a policy.
class InsuranceFormController extends GetxController {
  InsuranceFormController({
    required this.insuranceRepository,
    required this.vehicleRepository,
    this.editing,
  });

  final InsuranceRepository insuranceRepository;
  final CustomerVehicleRepository vehicleRepository;

  /// The policy being edited, or — when renewing — the one being replaced.
  final InsurancePolicyModel? editing;

  bool get isEditing => editing != null;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController companyController = TextEditingController();
  final TextEditingController policyNumberController = TextEditingController();
  final TextEditingController premiumController = TextEditingController();
  final TextEditingController sumInsuredController = TextEditingController();

  final Rxn<String> vehicleId = Rxn<String>();
  final Rx<InsurancePolicyType> policyType = InsurancePolicyType.comprehensive.obs;
  final Rxn<DateTime> startDate = Rxn<DateTime>(DateTime.now());
  final Rxn<DateTime> expiryDate = Rxn<DateTime>();

  final RxList<CustomerVehicleModel> vehicles = <CustomerVehicleModel>[].obs;
  final RxBool isLoadingVehicles = false.obs;
  final RxBool isSubmitting = false.obs;

  String? get showroomId =>
      Get.find<SessionController>().activeShowroomId.value;

  @override
  void onInit() {
    super.onInit();

    final InsurancePolicyModel? source = editing;
    if (source != null) {
      companyController.text = source.insuranceCompany;
      policyNumberController.text = source.policyNumber;
      premiumController.text = source.premium.toStringAsFixed(2);
      sumInsuredController.text = source.sumInsured.toStringAsFixed(2);
      vehicleId.value = source.vehicleId;
      policyType.value = source.policyType;
      startDate.value = source.startDate;
      expiryDate.value = source.expiryDate;
    } else {
      // A motor policy runs a year; pre-filling it saves the common case and
      // is freely overridden.
      expiryDate.value = DateUtil.addYears(DateTime.now(), 1);
    }

    unawaited(loadVehicles());
  }

  Future<void> loadVehicles() async {
    final String? id = showroomId;
    if (id == null) {
      return;
    }
    isLoadingVehicles.value = true;
    try {
      final PaginatedResponse<CustomerVehicleModel> page =
          await vehicleRepository.list(
            QueryParams(pageSize: 200, showroomId: id),
          );
      vehicles.assignAll(page.items);
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoadingVehicles.value = false;
    }
  }

  String? validatePremium(String? value) =>
      AppValidators.amount(value, field: 'Premium', isRequired: false);

  String? validateSumInsured(String? value) =>
      AppValidators.amount(value, field: 'Sum insured', isRequired: false);

  /// The database rejects an expiry before its start; saying so here puts the
  /// message next to the field instead of behind a constraint error.
  String? get dateRangeError {
    final DateTime? start = startDate.value;
    final DateTime? expiry = expiryDate.value;
    if (start != null && expiry != null && expiry.isBefore(start)) {
      return 'The policy cannot expire before it starts.';
    }
    return null;
  }

  Future<InsurancePolicyModel?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }
    if (vehicleId.value == null) {
      AppSnackbar.error('Select the vehicle this policy covers.');
      return null;
    }
    final String? rangeError = dateRangeError;
    if (rangeError != null) {
      AppSnackbar.error(rangeError);
      return null;
    }
    if (expiryDate.value == null) {
      AppSnackbar.error('Enter the expiry date.');
      return null;
    }

    final SessionController session = Get.find<SessionController>();
    final String permission = isEditing
        ? AppPermissions.insuranceEdit
        : AppPermissions.insuranceCreate;
    if (!session.can(permission)) {
      AppSnackbar.error('You do not have permission to do this.');
      return null;
    }

    final String? id = editing?.showroomId ?? showroomId;
    if (id == null) {
      AppSnackbar.error('Select a showroom first.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'vehicle_id': vehicleId.value,
        'insurance_company': companyController.text.trim(),
        'policy_number': policyNumberController.text.trim(),
        'policy_type': policyType.value.value,
        'start_date': DateUtil.toIsoDateOrNull(startDate.value),
        'expiry_date': DateUtil.toIsoDateOrNull(expiryDate.value),
        'premium': double.tryParse(premiumController.text.trim()) ?? 0,
        'sum_insured': double.tryParse(sumInsuredController.text.trim()) ?? 0,
      };

      final InsurancePolicyModel saved = isEditing
          ? await insuranceRepository.update(
              editing!.id,
              payload,
              expectedRevision: editing!.revision,
            )
          : await insuranceRepository.create(<String, Object?>{
              ...payload,
              'showroom_id': id,
            });

      AppSnackbar.success(isEditing ? 'Policy updated.' : 'Policy recorded.');
      return saved;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    companyController.dispose();
    policyNumberController.dispose();
    premiumController.dispose();
    sumInsuredController.dispose();
    super.onClose();
  }
}
