import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/showroom/controllers/showroom_controller.dart';
import 'package:bike_showroom_management_system/features/showroom/models/showroom_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Create or edit a showroom.
class ShowroomFormView extends GetView<ShowroomFormController> {
  const ShowroomFormView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(controller.isEditing ? 'Edit Showroom' : 'Add Showroom'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 720,
          padding: EdgeInsets.zero,
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Basic details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField(
                      label: 'Showroom name',
                      controller: controller.nameController,
                      validator: controller.validateName,
                      isRequired: true,
                    ),
                    AppTextField.code(
                      label: 'Showroom code',
                      controller: controller.codeController,
                      validator: controller.validateCode,
                      hint: 'e.g. MUM01',
                      isEnabled: !controller.isEditing,
                    ),
                  ],
                ),
                AppSpacing.gapLg,
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
                Text('Contact', style: Theme.of(context).textTheme.titleMedium),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.phone(
                      label: 'Phone',
                      controller: controller.phoneController,
                      validator: controller.validatePhone,
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
                AppSpacing.gapXxl,
                Text(
                  'Tax and billing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.code(
                      label: 'GST number',
                      controller: controller.gstController,
                      validator: controller.validateGst,
                      isRequired: false,
                      maxLength: 15,
                    ),
                    AppTextField.code(
                      label: 'PAN number',
                      controller: controller.panController,
                      validator: controller.validatePan,
                      isRequired: false,
                      maxLength: 10,
                    ),
                    AppTextField.code(
                      label: 'Invoice prefix',
                      controller: controller.invoicePrefixController,
                      isRequired: false,
                      hint: 'e.g. MUM',
                      maxLength: 10,
                    ),
                  ],
                ),
                AppSpacing.gapXxl,
                Row(
                  children: <Widget>[
                    AppButton.ghost(label: 'Cancel', onPressed: Get.back),
                    const Spacer(),
                    Obx(
                      () => AppButton.primary(
                        label: controller.isEditing
                            ? 'Save changes'
                            : 'Create showroom',
                        isLoading: controller.isSubmitting.value,
                        onPressed: () async {
                          final ShowroomModel? saved = await controller
                              .submit();
                          if (saved != null) {
                            Get.back(result: saved);
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
