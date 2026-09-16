import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/service/models/service_item_model.dart';
import 'package:bike_showroom_management_system/features/service/models/service_record_model.dart';
import 'package:bike_showroom_management_system/features/service/repositories/service_repository.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';
import 'package:bike_showroom_management_system/features/vehicles/repositories/customer_vehicle_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the job-card list for the active showroom.
class ServiceController extends ListController<ServiceRecordModel> {
  ServiceController({required ServiceRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['service_number', 'complaint'],
      );

  final Rxn<ServiceStatus> statusFilter = Rxn<ServiceStatus>();
  final Rxn<ServiceType> typeFilter = Rxn<ServiceType>();

  void filterByStatus(ServiceStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter('service_status');
    } else {
      applyFilter(QueryFilter.equals('service_status', status.value));
    }
  }

  void filterByType(ServiceType? type) {
    typeFilter.value = type;
    if (type == null) {
      removeFilter('service_type');
    } else {
      applyFilter(QueryFilter.equals('service_type', type.value));
    }
  }

  void filterByDateRange(DateRange? range) =>
      setDateRange(range, dateColumn: 'service_date');

  /// The workshop board: everything not yet finished.
  void showOpenOnly() {
    statusFilter.value = null;
    params.value = params.value
        .withFilter(
          QueryFilter.inList('service_status', <String>[
            ServiceStatus.booked.value,
            ServiceStatus.received.value,
            ServiceStatus.inProgress.value,
            ServiceStatus.waitingForParts.value,
          ]),
        )
        .resetPage();
    reload();
  }
}

/// Books a job card.
class ServiceBookingController extends GetxController {
  ServiceBookingController({
    required this.serviceRepository,
    required this.vehicleRepository,
  });

  final ServiceRepository serviceRepository;
  final CustomerVehicleRepository vehicleRepository;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController odometerController = TextEditingController();
  final TextEditingController complaintController = TextEditingController();

  final Rxn<String> vehicleId = Rxn<String>();
  final Rx<ServiceType> serviceType = ServiceType.paid.obs;
  final Rxn<DateTime> serviceDate = Rxn<DateTime>(DateTime.now());

  final RxList<CustomerVehicleModel> vehicles = <CustomerVehicleModel>[].obs;
  final RxBool isLoadingVehicles = false.obs;
  final RxBool isSubmitting = false.obs;

  /// The free-service answer for the selected vehicle, straight from
  /// `check_free_service_eligibility`.
  final Rxn<String> freeServiceIssue = Rxn<String>();
  final RxBool isCheckingEligibility = false.obs;

  String? get showroomId =>
      Get.find<SessionController>().activeShowroomId.value;

  CustomerVehicleModel? get selectedVehicle {
    final String? id = vehicleId.value;
    if (id == null) {
      return null;
    }
    for (final CustomerVehicleModel vehicle in vehicles) {
      if (vehicle.id == id) {
        return vehicle;
      }
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(loadVehicles());
  }

  Future<void> loadVehicles() async {
    final String? id = showroomId;
    if (id == null) {
      AppSnackbar.error('Select a showroom before booking a service.');
      return;
    }
    isLoadingVehicles.value = true;
    try {
      final PaginatedResponse<CustomerVehicleModel> page = await vehicleRepository
          .list(
            QueryParams(
              pageSize: 200,
              showroomId: id,
              filters: <QueryFilter>[
                // Only a live vehicle can be serviced; a scrapped or resold
                // one has no owner to hand it back to.
                QueryFilter.equals('status', VehicleStatus.active.value),
              ],
            ),
          );
      vehicles.assignAll(page.items);
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoadingVehicles.value = false;
    }
  }

  /// Pre-fills the odometer and asks the server whether a free service is due.
  Future<void> selectVehicle(String? id) async {
    vehicleId.value = id;
    freeServiceIssue.value = null;

    final CustomerVehicleModel? vehicle = selectedVehicle;
    if (vehicle == null) {
      return;
    }
    // Seeded from the last known reading, which is also the floor the
    // monotonic guard enforces.
    odometerController.text = vehicle.currentOdometer.toString();
    await refreshEligibility();
  }

  /// Checks the free-service entitlement now rather than at completion.
  ///
  /// `complete_service` raises the same check as a hard error; asking here
  /// means the advisor picks the right service type up front instead of
  /// discovering at handover that the visit is chargeable after all.
  Future<void> refreshEligibility() async {
    final String? id = vehicleId.value;
    if (id == null) {
      return;
    }
    isCheckingEligibility.value = true;
    try {
      final Map<String, Object?> result = await serviceRepository
          .checkFreeServiceEligibility(
            vehicleId: id,
            odometer: int.tryParse(odometerController.text.trim()),
          );
      final bool eligible = result['eligible'] == true;
      freeServiceIssue.value = eligible
          ? null
          : (result['reason']?.toString() ?? 'No free service is due.');
    } on Object {
      // Advisory only — booking must not be blocked by a failed lookup.
      freeServiceIssue.value = null;
    } finally {
      isCheckingEligibility.value = false;
    }
  }

  String? validateOdometer(String? value) => AppValidators.odometer(
    value,
    previousReading: selectedVehicle?.currentOdometer ?? 0,
  );

  String? get blockingIssue {
    if (vehicleId.value == null) {
      return 'Select the vehicle being serviced.';
    }
    if (serviceType.value == ServiceType.free &&
        freeServiceIssue.value != null) {
      // The server refuses this at completion, so booking it as FREE would
      // strand the job card.
      return freeServiceIssue.value;
    }
    return null;
  }

  Future<ServiceRecordModel?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }
    final String? issue = blockingIssue;
    if (issue != null) {
      AppSnackbar.error(issue);
      return null;
    }

    final SessionController session = Get.find<SessionController>();
    if (!session.can(AppPermissions.serviceCreate)) {
      AppSnackbar.error('You do not have permission to book a service.');
      return null;
    }
    final String? id = showroomId;
    final CustomerVehicleModel? vehicle = selectedVehicle;
    if (id == null || vehicle == null) {
      AppSnackbar.error('Select a showroom and a vehicle.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final ServiceRecordModel created = await serviceRepository
          .create(<String, Object?>{
            'showroom_id': id,
            'customer_id': vehicle.customerId,
            'vehicle_id': vehicle.id,
            'service_number': await serviceRepository.nextServiceNumber(id),
            'booking_date': DateUtil.toIsoDate(DateTime.now()),
            'service_date': DateUtil.toIsoDateOrNull(serviceDate.value),
            'odometer_reading':
                int.tryParse(odometerController.text.trim()) ?? 0,
            'service_type': serviceType.value.value,
            'service_status': ServiceStatus.booked.value,
            'service_advisor_id': session.userId,
            if (complaintController.text.trim().isNotEmpty)
              'complaint': complaintController.text.trim(),
          });
      AppSnackbar.success('Job card ${created.serviceNumber} booked.');
      return created;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    odometerController.dispose();
    complaintController.dispose();
    super.onClose();
  }
}

/// Works one job card: its lines, its status and its completion.
class ServiceDetailsController extends GetxController {
  ServiceDetailsController({
    required this.serviceRepository,
    required this.service,
  });

  final ServiceRepository serviceRepository;

  /// The list's row, shown while the full record loads.
  final ServiceRecordModel service;

  late final Rx<ServiceRecordModel> detail = service.obs;

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      detail.value = await serviceRepository.getDetail(service.id);
    } on Object catch (e, stackTrace) {
      final AppException mapped = ErrorMapper.map(e, stackTrace);
      error.value = mapped;
      AppSnackbar.fromException(mapped);
    } finally {
      isLoading.value = false;
    }
  }

  /// Moves the job card along the workshop board.
  Future<void> setStatus(ServiceStatus status) async {
    if (!Get.find<SessionController>().can(AppPermissions.serviceEdit)) {
      AppSnackbar.error('You do not have permission to update a job card.');
      return;
    }
    isSaving.value = true;
    try {
      await serviceRepository.update(detail.value.id, <String, Object?>{
        'service_status': status.value,
      });
      AppSnackbar.success('Job card is now ${status.label.toLowerCase()}.');
      await load();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isSaving.value = false;
    }
  }

  /// Adds a line.
  ///
  /// [isChargeable] false records work done under warranty or a free service:
  /// costed, but never billed — `complete_service` totals only the chargeable
  /// lines.
  Future<bool> addItem({
    required ServiceItemType itemType,
    required String description,
    required double quantity,
    required double unitPrice,
    required double taxRate,
    required bool isChargeable,
  }) async {
    if (!Get.find<SessionController>().can(AppPermissions.serviceEdit)) {
      AppSnackbar.error('You do not have permission to update a job card.');
      return false;
    }
    if (description.trim().isEmpty) {
      AppSnackbar.error('Describe the part or the work.');
      return false;
    }

    final double gross = quantity * unitPrice;
    final double tax = gross * taxRate / 100;

    isSaving.value = true;
    try {
      await serviceRepository.addItem(<String, Object?>{
        'service_id': detail.value.id,
        'item_type': itemType.value,
        'description': description.trim(),
        'quantity': quantity,
        'unit_price': unitPrice,
        'tax_rate': taxRate,
        'tax_amount': tax,
        'total_amount': gross + tax,
        'is_chargeable': isChargeable,
      });
      await load();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> removeItem(ServiceItemModel item) async {
    try {
      await serviceRepository.removeItem(item.id);
      await load();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }

  /// Completes the job card through the RPC.
  Future<ServiceCompletionResult?> complete({
    double additionalDiscount = 0,
    String? workDone,
  }) async {
    if (!Get.find<SessionController>().can(AppPermissions.serviceComplete)) {
      AppSnackbar.error('You do not have permission to complete a service.');
      return null;
    }

    isSaving.value = true;
    try {
      final ServiceCompletionResult result = await serviceRepository.complete(
        serviceId: detail.value.id,
        additionalDiscount: additionalDiscount,
        workDone: workDone,
      );
      AppSnackbar.success(
        result.raisedInvoice
            ? 'Service completed and invoiced.'
            : 'Service completed. Nothing was chargeable, so no invoice was '
                  'raised.',
      );
      await load();
      return result;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return null;
    } finally {
      isSaving.value = false;
    }
  }
}
