import 'dart:async';

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
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';
import 'package:bike_showroom_management_system/features/vehicles/repositories/customer_vehicle_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the customer-vehicle list, either branch-wide or for one customer.
class VehicleController extends ListController<CustomerVehicleModel> {
  VehicleController({
    required CustomerVehicleRepository repository,
    this.customer,
  }) : super(
         repository: repository,
         searchColumns: const <String>[
           'registration_number',
           'chassis_number',
           'engine_number',
         ],
       );

  /// Set when the screen was opened from a customer record.
  final CustomerModel? customer;

  String get title =>
      customer == null ? 'Vehicles' : 'Vehicles - ${customer!.name}';

  @override
  void onInit() {
    final CustomerModel? source = customer;
    if (source != null) {
      params.value = params.value.withFilter(
        QueryFilter.equals('customer_id', source.id),
      );
    }
    super.onInit();
  }
}

/// Owns the create/edit form for one customer vehicle.
class VehicleFormController extends GetxController {
  VehicleFormController({
    required this.vehicleRepository,
    required this.customerRepository,
    required this.productRepository,
    CustomerVehicleModel? existing,
    this.presetCustomer,
  }) : editing = existing;

  final CustomerVehicleRepository vehicleRepository;
  final CustomerRepository customerRepository;
  final ProductRepository productRepository;

  final CustomerVehicleModel? editing;
  final CustomerModel? presetCustomer;

  bool get isEditing => editing != null;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController chassisController = TextEditingController();
  final TextEditingController engineController = TextEditingController();
  final TextEditingController registrationController = TextEditingController();
  final TextEditingController odometerController = TextEditingController();
  final TextEditingController nextServiceKmController = TextEditingController();

  final Rxn<String> customerId = Rxn<String>();
  final Rxn<String> productId = Rxn<String>();
  final Rxn<DateTime> registrationDate = Rxn<DateTime>();
  final Rxn<DateTime> purchaseDate = Rxn<DateTime>();
  final Rxn<DateTime> deliveryDate = Rxn<DateTime>();
  final Rxn<DateTime> warrantyStart = Rxn<DateTime>();
  final Rxn<DateTime> warrantyEnd = Rxn<DateTime>();
  final Rxn<DateTime> insuranceStart = Rxn<DateTime>();
  final Rxn<DateTime> insuranceEnd = Rxn<DateTime>();
  final Rxn<DateTime> nextServiceDate = Rxn<DateTime>();
  final Rx<VehicleStatus> status = VehicleStatus.active.obs;

  final RxList<CustomerModel> customers = <CustomerModel>[].obs;
  final RxList<ProductModel> products = <ProductModel>[].obs;

  final RxBool isLoadingOptions = false.obs;
  final RxBool isSubmitting = false.obs;

  /// The reading this vehicle already has. A new one may not be below it.
  int get previousOdometer => editing?.currentOdometer ?? 0;

  @override
  void onInit() {
    super.onInit();

    final CustomerVehicleModel? source = editing;
    if (source != null) {
      chassisController.text = source.chassisNumber;
      engineController.text = source.engineNumber;
      registrationController.text = source.registrationNumber ?? '';
      odometerController.text = source.currentOdometer.toString();
      nextServiceKmController.text = source.nextServiceKm?.toString() ?? '';
      customerId.value = source.customerId;
      productId.value = source.productId;
      registrationDate.value = source.registrationDate;
      purchaseDate.value = source.purchaseDate;
      deliveryDate.value = source.deliveryDate;
      warrantyStart.value = source.warrantyStart;
      warrantyEnd.value = source.warrantyEnd;
      insuranceStart.value = source.insuranceStart;
      insuranceEnd.value = source.insuranceEnd;
      nextServiceDate.value = source.nextServiceDate;
      status.value = source.status;
    } else {
      customerId.value = presetCustomer?.id;
      odometerController.text = '0';
    }

    unawaited(_loadOptions());
  }

  Future<void> _loadOptions() async {
    final String? showroomId =
        Get.find<SessionController>().activeShowroomId.value;
    isLoadingOptions.value = true;
    try {
      products.assignAll(
        await productRepository.listSelectable(vehiclesOnly: true),
      );
      if (showroomId != null) {
        customers.assignAll(
          await customerRepository.listSelectable(showroomId),
        );
      }
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoadingOptions.value = false;
    }
  }

  /// Fills the warranty window from the product's own warranty period, so the
  /// common case needs no typing. Overwritten freely if the dealer agreed
  /// something else.
  void applyWarrantyFromProduct() {
    final String? id = productId.value;
    final DateTime? start = deliveryDate.value ?? purchaseDate.value;
    if (id == null || start == null) {
      return;
    }
    for (final ProductModel product in products) {
      if (product.id == id) {
        warrantyStart.value = start;
        warrantyEnd.value = DateUtil.addMonths(start, product.warrantyMonths);
        return;
      }
    }
  }

  // ------------------------------------------------------------ validation

  String? validateChassis(String? value) => AppValidators.chassisNumber(value);

  String? validateEngine(String? value) => AppValidators.engineNumber(value);

  String? validateRegistration(String? value) =>
      AppValidators.registrationNumber(value);

  String? validateOdometer(String? value) =>
      AppValidators.odometer(value, previousReading: previousOdometer);

  /// The database rejects an end before its start; catching it here says so
  /// next to the field instead of as a constraint error after submit.
  String? get dateRangeError {
    if (warrantyStart.value != null &&
        warrantyEnd.value != null &&
        warrantyEnd.value!.isBefore(warrantyStart.value!)) {
      return 'Warranty end cannot be before warranty start.';
    }
    if (insuranceStart.value != null &&
        insuranceEnd.value != null &&
        insuranceEnd.value!.isBefore(insuranceStart.value!)) {
      return 'Insurance end cannot be before insurance start.';
    }
    return null;
  }

  // ----------------------------------------------------------------- submit

  Future<CustomerVehicleModel?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }
    if (customerId.value == null) {
      AppSnackbar.error('Select the customer who owns this vehicle.');
      return null;
    }
    if (productId.value == null) {
      AppSnackbar.error('Select the model.');
      return null;
    }
    final String? rangeError = dateRangeError;
    if (rangeError != null) {
      AppSnackbar.error(rangeError);
      return null;
    }

    final SessionController session = Get.find<SessionController>();
    final String permission = isEditing
        ? AppPermissions.vehiclesEdit
        : AppPermissions.vehiclesCreate;
    if (!session.can(permission)) {
      AppSnackbar.error('You do not have permission to do this.');
      return null;
    }

    final String? showroomId =
        editing?.showroomId ?? session.activeShowroomId.value;
    if (showroomId == null) {
      AppSnackbar.error('Select a showroom first.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'customer_id': customerId.value,
        'product_id': productId.value,
        'chassis_number': chassisController.text.trim().toUpperCase(),
        'engine_number': engineController.text.trim().toUpperCase(),
        'registration_number': _orNull(
          registrationController.text,
        )?.toUpperCase(),
        'registration_date': DateUtil.toIsoDateOrNull(registrationDate.value),
        'purchase_date': DateUtil.toIsoDateOrNull(purchaseDate.value),
        'delivery_date': DateUtil.toIsoDateOrNull(deliveryDate.value),
        'current_odometer': int.tryParse(odometerController.text.trim()) ?? 0,
        'warranty_start': DateUtil.toIsoDateOrNull(warrantyStart.value),
        'warranty_end': DateUtil.toIsoDateOrNull(warrantyEnd.value),
        'insurance_start': DateUtil.toIsoDateOrNull(insuranceStart.value),
        'insurance_end': DateUtil.toIsoDateOrNull(insuranceEnd.value),
        'next_service_date': DateUtil.toIsoDateOrNull(nextServiceDate.value),
        'next_service_km': int.tryParse(nextServiceKmController.text.trim()),
        'status': status.value.value,
      };

      final CustomerVehicleModel saved = isEditing
          ? await vehicleRepository.update(
              editing!.id,
              payload,
              expectedRevision: editing!.revision,
            )
          : await vehicleRepository.create(<String, Object?>{
              ...payload,
              'showroom_id': showroomId,
            });

      AppSnackbar.success(isEditing ? 'Vehicle updated.' : 'Vehicle added.');
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
    chassisController.dispose();
    engineController.dispose();
    registrationController.dispose();
    odometerController.dispose();
    nextServiceKmController.dispose();
    super.onClose();
  }
}
