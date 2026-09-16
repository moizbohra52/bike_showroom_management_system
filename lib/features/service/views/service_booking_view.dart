import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/service/controllers/service_controller.dart';
import 'package:bike_showroom_management_system/features/service/models/service_record_model.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Book a job card against a customer vehicle.
class ServiceBookingView extends GetView<ServiceBookingController> {
  const ServiceBookingView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Book Service')),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 760,
          padding: EdgeInsets.zero,
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Obx(
                  () => AppDropdown<CustomerVehicleModel>(
                    label: 'Vehicle',
                    hint: controller.isLoadingVehicles.value
                        ? 'Loading...'
                        : 'Select the vehicle',
                    items: controller.vehicles.toList(),
                    itemLabel: (CustomerVehicleModel v) =>
                        '${v.displayIdentifier} - ${v.customerName ?? ""}',
                    value: controller.vehicles.firstWhereOrNull(
                      (CustomerVehicleModel v) =>
                          v.id == controller.vehicleId.value,
                    ),
                    isRequired: true,
                    onChanged: (CustomerVehicleModel? v) =>
                        controller.selectVehicle(v?.id),
                  ),
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<ServiceType>(
                        label: 'Service type',
                        items: ServiceType.values,
                        itemLabel: (ServiceType t) => t.label,
                        value: controller.serviceType.value,
                        isRequired: true,
                        onChanged: (ServiceType? t) {
                          if (t != null) {
                            controller.serviceType.value = t;
                          }
                        },
                      ),
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Service date',
                        value: controller.serviceDate.value,
                        onChanged: (DateTime? d) =>
                            controller.serviceDate.value = d,
                      ),
                    ),
                    AppTextField.integer(
                      label: 'Odometer (km)',
                      controller: controller.odometerController,
                      validator: controller.validateOdometer,
                      helper: 'Cannot be below the last reading',
                      onChanged: (_) => controller.refreshEligibility(),
                    ),
                  ],
                ),

                const _FreeServiceNote(),

                AppSpacing.gapLg,
                AppTextField.multiline(
                  label: 'Customer complaint',
                  controller: controller.complaintController,
                  maxLines: 3,
                  hint: 'What the customer reported',
                ),

                AppSpacing.gapXxl,
                Obx(() {
                  final String? issue = controller.blockingIssue;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (issue != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.info_outline,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              AppSpacing.hGapSm,
                              Expanded(
                                child: Text(
                                  issue,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: <Widget>[
                          AppButton.ghost(
                            label: 'Cancel',
                            onPressed: Get.back<void>,
                          ),
                          const Spacer(),
                          AppButton.primary(
                            label: 'Book job card',
                            isLoading: controller.isSubmitting.value,
                            onPressed: () async {
                              final ServiceRecordModel? saved =
                                  await controller.submit();
                              if (saved != null) {
                                Get.back<ServiceRecordModel>(result: saved);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Says whether a free service is actually due on this vehicle.
///
/// The answer comes from `check_free_service_eligibility` — the same function
/// `complete_service` raises as a hard error — so the advisor picks the right
/// service type up front rather than discovering at handover that the visit is
/// chargeable after all.
class _FreeServiceNote extends StatelessWidget {
  const _FreeServiceNote();

  @override
  Widget build(BuildContext context) {
    final ServiceBookingController controller =
        Get.find<ServiceBookingController>();

    return Obx(() {
      if (controller.vehicleId.value == null) {
        return const SizedBox.shrink();
      }
      if (controller.isCheckingEligibility.value) {
        return const Padding(
          padding: EdgeInsets.only(top: AppSpacing.md),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              AppSpacing.hGapSm,
              Text('Checking free-service entitlement...'),
            ],
          ),
        );
      }

      final String? issue = controller.freeServiceIssue.value;
      final bool eligible = issue == null;
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: AppCard(
          child: Row(
            children: <Widget>[
              Icon(
                eligible ? Icons.check_circle_outline : Icons.info_outline,
                size: 18,
                color: eligible ? AppColors.success : AppColors.warning,
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Text(
                  eligible
                      ? 'A free service is due on this vehicle.'
                      : issue,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
