import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/vehicles/controllers/vehicle_controller.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Create or edit a customer-owned vehicle.
class VehicleFormView extends GetView<VehicleFormController> {
  const VehicleFormView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(controller.isEditing ? 'Edit Vehicle' : 'Add Vehicle'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 860,
          padding: EdgeInsets.zero,
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SectionTitle('Owner and model'),
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<CustomerModel>(
                        label: 'Customer',
                        hint: controller.isLoadingOptions.value
                            ? 'Loading...'
                            : 'Select the owner',
                        items: controller.customers.toList(),
                        itemLabel: (CustomerModel c) =>
                            '${c.name} (${c.phone})',
                        value: controller.customers.firstWhereOrNull(
                          (CustomerModel c) =>
                              c.id == controller.customerId.value,
                        ),
                        isRequired: true,
                        // The owner changes through a transfer, not by editing
                        // the record: the vehicle's service and warranty
                        // history belongs to whoever owned it at the time.
                        isEnabled: !controller.isEditing,
                        onChanged: (CustomerModel? value) =>
                            controller.customerId.value = value?.id,
                      ),
                    ),
                    Obx(
                      () => AppDropdown<ProductModel>(
                        label: 'Model',
                        hint: 'Select the model',
                        items: controller.products.toList(),
                        itemLabel: (ProductModel p) => p.displayName,
                        value: controller.products.firstWhereOrNull(
                          (ProductModel p) =>
                              p.id == controller.productId.value,
                        ),
                        isRequired: true,
                        isEnabled: !controller.isEditing,
                        onChanged: (ProductModel? value) =>
                            controller.productId.value = value?.id,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.code(
                      label: 'Chassis number',
                      controller: controller.chassisController,
                      validator: controller.validateChassis,
                      maxLength: 25,
                      isEnabled: !controller.isEditing,
                    ),
                    AppTextField.code(
                      label: 'Engine number',
                      controller: controller.engineController,
                      validator: controller.validateEngine,
                      maxLength: 25,
                      isEnabled: !controller.isEditing,
                    ),
                  ],
                ),

                AppSpacing.gapXxl,
                _SectionTitle('Registration and delivery'),
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.code(
                      label: 'Registration number',
                      controller: controller.registrationController,
                      validator: controller.validateRegistration,
                      isRequired: false,
                      hint: 'MP09AB1234',
                      maxLength: 11,
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Registration date',
                        value: controller.registrationDate.value,
                        onChanged: (DateTime? value) =>
                            controller.registrationDate.value = value,
                      ),
                    ),
                    AppTextField.integer(
                      label: 'Odometer (km)',
                      controller: controller.odometerController,
                      validator: controller.validateOdometer,
                      isRequired: false,
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDatePicker(
                        label: 'Purchase date',
                        value: controller.purchaseDate.value,
                        lastDate: DateTime.now(),
                        onChanged: (DateTime? value) =>
                            controller.purchaseDate.value = value,
                      ),
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Delivery date',
                        value: controller.deliveryDate.value,
                        onChanged: (DateTime? value) =>
                            controller.deliveryDate.value = value,
                      ),
                    ),
                    Obx(
                      () => AppDropdown<VehicleStatus>(
                        label: 'Status',
                        items: VehicleStatus.values,
                        itemLabel: (VehicleStatus s) => s.label,
                        value: controller.status.value,
                        onChanged: (VehicleStatus? value) {
                          if (value != null) {
                            controller.status.value = value;
                          }
                        },
                      ),
                    ),
                  ],
                ),

                AppSpacing.gapXxl,
                Row(
                  children: <Widget>[
                    Expanded(child: _SectionTitle('Warranty')),
                    AppButton.ghost(
                      label: 'Fill from product',
                      icon: Icons.auto_fix_high_outlined,
                      size: AppButtonSize.small,
                      onPressed: controller.applyWarrantyFromProduct,
                    ),
                  ],
                ),
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDatePicker(
                        label: 'Warranty start',
                        value: controller.warrantyStart.value,
                        onChanged: (DateTime? value) =>
                            controller.warrantyStart.value = value,
                      ),
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Warranty end',
                        value: controller.warrantyEnd.value,
                        onChanged: (DateTime? value) =>
                            controller.warrantyEnd.value = value,
                      ),
                    ),
                  ],
                ),

                AppSpacing.gapXxl,
                _SectionTitle('Insurance and service'),
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDatePicker(
                        label: 'Insurance start',
                        value: controller.insuranceStart.value,
                        onChanged: (DateTime? value) =>
                            controller.insuranceStart.value = value,
                      ),
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Insurance end',
                        value: controller.insuranceEnd.value,
                        onChanged: (DateTime? value) =>
                            controller.insuranceEnd.value = value,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDatePicker(
                        label: 'Next service due',
                        value: controller.nextServiceDate.value,
                        onChanged: (DateTime? value) =>
                            controller.nextServiceDate.value = value,
                      ),
                    ),
                    AppTextField.integer(
                      label: 'Next service at (km)',
                      controller: controller.nextServiceKmController,
                      isRequired: false,
                    ),
                  ],
                ),

                Obx(() {
                  final String? error = controller.dateRangeError;
                  if (error == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                          size: 18,
                        ),
                        AppSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            error,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                AppSpacing.gapXxl,
                Row(
                  children: <Widget>[
                    AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
                    const Spacer(),
                    Obx(
                      () => AppButton.primary(
                        label: controller.isEditing
                            ? 'Save changes'
                            : 'Add vehicle',
                        isLoading: controller.isSubmitting.value,
                        onPressed: () async {
                          final CustomerVehicleModel? saved = await controller
                              .submit();
                          if (saved != null) {
                            Get.back<CustomerVehicleModel>(result: saved);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
