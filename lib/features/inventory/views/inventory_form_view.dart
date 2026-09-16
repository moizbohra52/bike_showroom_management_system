import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/features/inventory/controllers/inventory_controller.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_color_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Take one machine into stock, or correct its details.
class InventoryFormView extends GetView<InventoryFormController> {
  const InventoryFormView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(controller.isEditing ? 'Edit Stock' : 'Add Stock'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 780,
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
                      'Stock code ${controller.editing!.stockCode}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),

                _SectionTitle('Vehicle'),
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<ProductModel>(
                        label: 'Product',
                        hint: controller.isLoadingProducts.value
                            ? 'Loading...'
                            : 'Select a model',
                        items: controller.products.toList(),
                        itemLabel: (ProductModel p) => p.displayName,
                        value: controller.products.firstWhereOrNull(
                          (ProductModel p) =>
                              p.id == controller.productId.value,
                        ),
                        isRequired: true,
                        // Changing the model on a unit already in stock would
                        // silently rewrite what a physical machine is; the
                        // chassis number is the machine's identity.
                        isEnabled: !controller.isEditing,
                        onChanged: (ProductModel? product) =>
                            controller.selectProduct(product?.id),
                      ),
                    ),
                    Obx(
                      () => AppDropdown<ProductColorModel>(
                        label: 'Colour',
                        hint: controller.availableColors.isEmpty
                            ? 'No colours defined'
                            : 'Select a colour',
                        items: controller.availableColors,
                        itemLabel: (ProductColorModel c) => c.colorName,
                        value: controller.availableColors.firstWhereOrNull(
                          (ProductColorModel c) =>
                              c.id == controller.colorId.value,
                        ),
                        isEnabled: controller.availableColors.isNotEmpty,
                        onChanged: (ProductColorModel? color) =>
                            controller.colorId.value = color?.id,
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
                      // Immutable once created: the chassis number identifies
                      // the machine, and correcting a typo on a unit that has
                      // already moved would break its history.
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
                _SectionTitle('Intake'),
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
                    AppTextField.money(
                      label: 'Purchase price',
                      controller: controller.purchasePriceController,
                      validator: controller.validatePurchasePrice,
                      isRequired: false,
                    ),
                    AppTextField.integer(
                      label: 'Model year',
                      controller: controller.modelYearController,
                      validator: controller.validateModelYear,
                      isRequired: false,
                      maxLength: 4,
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDatePicker(
                        label: 'Manufacturing date',
                        value: controller.manufacturingDate.value,
                        lastDate: DateTime.now(),
                        onChanged: (DateTime? value) =>
                            controller.manufacturingDate.value = value,
                      ),
                    ),
                    AppTextField(
                      label: 'Location',
                      controller: controller.locationController,
                      hint: 'e.g. Floor A, Bay 3',
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppTextField.multiline(
                  label: 'Notes',
                  controller: controller.notesController,
                  maxLines: 2,
                ),

                if (controller.isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Text(
                      'Status is changed from the stock list, where a reason '
                      'is required. That reason replaces the notes above, and '
                      'the movement itself is recorded in the history.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
                            : 'Add to stock',
                        isLoading: controller.isSubmitting.value,
                        onPressed: () async {
                          final InventoryModel? saved = await controller
                              .submit();
                          if (saved != null) {
                            Get.back<InventoryModel>(result: saved);
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
