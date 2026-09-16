import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/customers/controllers/customer_controller.dart';
import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Create or edit a customer.
class CustomerFormView extends GetView<CustomerFormController> {
  const CustomerFormView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(controller.isEditing ? 'Edit Customer' : 'Add Customer'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 820,
          padding: EdgeInsets.zero,
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (controller.isEditing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Text(
                      'Customer ${controller.editing!.customerCode}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),

                _SectionTitle('Identity'),
                AppFieldRow(
                  children: <Widget>[
                    AppTextField(
                      label: 'Full name',
                      controller: controller.nameController,
                      validator: controller.validateName,
                      isRequired: true,
                      textCapitalization: TextCapitalization.words,
                    ),
                    Obx(
                      () => AppDropdown<CustomerType>(
                        label: 'Customer type',
                        items: CustomerType.values,
                        itemLabel: (CustomerType t) => t.label,
                        value: controller.customerType.value,
                        isRequired: true,
                        onChanged: (CustomerType? value) {
                          if (value != null) {
                            controller.customerType.value = value;
                          }
                        },
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.phone(
                      label: 'Phone',
                      controller: controller.phoneController,
                      validator: controller.validatePhone,
                      onChanged: (_) => controller.checkForDuplicate(),
                    ),
                    AppTextField.phone(
                      label: 'Alternate phone',
                      controller: controller.alternatePhoneController,
                      validator: controller.validateAlternatePhone,
                      isRequired: false,
                    ),
                    AppTextField.email(
                      label: 'Email',
                      controller: controller.emailController,
                      validator: controller.validateEmail,
                      isRequired: false,
                    ),
                  ],
                ),
                const _DuplicateWarning(),

                AppSpacing.gapXxl,
                _SectionTitle('Address'),
                AppTextField.multiline(
                  label: 'Address',
                  controller: controller.addressController,
                  maxLines: 2,
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField(
                      label: 'City',
                      controller: controller.cityController,
                    ),
                    AppTextField(
                      label: 'State',
                      controller: controller.stateController,
                    ),
                    AppTextField.integer(
                      label: 'PIN code',
                      controller: controller.pincodeController,
                      validator: controller.validatePincode,
                      isRequired: false,
                      maxLength: 6,
                    ),
                  ],
                ),

                AppSpacing.gapXxl,
                _SectionTitle('Tax and personal'),
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppTextField.code(
                        label: 'GST number',
                        controller: controller.gstController,
                        validator: controller.validateGst,
                        isRequired:
                            controller.customerType.value !=
                            CustomerType.individual,
                        maxLength: 15,
                      ),
                    ),
                    AppTextField.code(
                      label: 'PAN number',
                      controller: controller.panController,
                      validator: controller.validatePan,
                      isRequired: false,
                      maxLength: 10,
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Date of birth',
                        value: controller.dateOfBirth.value,
                        lastDate: DateTime.now(),
                        onChanged: (DateTime? value) =>
                            controller.dateOfBirth.value = value,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<RecordStatus>(
                        label: 'Status',
                        items: RecordStatus.values,
                        itemLabel: (RecordStatus s) => s.label,
                        value: controller.status.value,
                        onChanged: (RecordStatus? value) {
                          if (value != null) {
                            controller.status.value = value;
                          }
                        },
                      ),
                    ),
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                  ],
                ),
                AppSpacing.gapLg,
                AppTextField.multiline(
                  label: 'Notes',
                  controller: controller.notesController,
                  maxLines: 2,
                ),

                AppSpacing.gapXxl,
                Row(
                  children: <Widget>[
                    AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
                    const Spacer(),
                    Obx(
                      () => AppButton.primary(
                        label: controller.isEditing
                            ? 'Save changes'
                            : 'Create customer',
                        isLoading: controller.isSubmitting.value,
                        onPressed: () async {
                          final CustomerModel? saved = await controller
                              .submit();
                          if (saved != null) {
                            Get.back<CustomerModel>(result: saved);
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

/// Shown when the typed phone number already belongs to someone at this
/// branch. Advisory rather than blocking: a family sharing one number is a
/// real case, and the unique index decides the actual outcome.
class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning();

  @override
  Widget build(BuildContext context) {
    final CustomerFormController controller =
        Get.find<CustomerFormController>();
    return Obx(() {
      final CustomerModel? existing = controller.duplicate.value;
      if (existing == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: AppCard(
          child: Row(
            children: <Widget>[
              const Icon(Icons.info_outline, color: AppColors.warning),
              AppSpacing.hGapMd,
              Expanded(
                child: Text(
                  '${existing.name} (${existing.customerCode}) already uses '
                  'this phone number at this showroom.',
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
