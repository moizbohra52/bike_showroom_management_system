import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/roles/controllers/role_controller.dart';
import 'package:bike_showroom_management_system/features/roles/models/role_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Create or rename a custom role. Permission assignment happens on the
/// dedicated matrix screen straight after creation.
class RoleFormView extends GetView<RoleFormController> {
  const RoleFormView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(controller.isEditing ? 'Rename Role' : 'Add Role'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 520,
          padding: EdgeInsets.zero,
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  label: 'Role name',
                  controller: controller.nameController,
                  validator: controller.validateName,
                  isRequired: true,
                  textCapitalization: TextCapitalization.characters,
                  hint: 'e.g. REGIONAL AUDITOR',
                ),
                AppSpacing.gapLg,
                AppTextField.multiline(
                  label: 'Description',
                  controller: controller.descriptionController,
                  maxLines: 3,
                  hint: 'What this role is for, and who should hold it',
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
                            : 'Create role',
                        isLoading: controller.isSubmitting.value,
                        onPressed: () async {
                          final RoleModel? saved = await controller.submit();
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
