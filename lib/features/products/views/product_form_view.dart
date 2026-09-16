import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/products/controllers/product_controller.dart';
import 'package:bike_showroom_management_system/features/products/models/brand_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_color_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Create or edit a catalogue product.
class ProductFormView extends GetView<ProductFormController> {
  const ProductFormView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(controller.isEditing ? 'Edit Product' : 'Add Product'),
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
                _SectionTitle('Basic details'),
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<BrandModel>(
                        label: 'Brand',
                        hint: controller.isLoadingBrands.value
                            ? 'Loading...'
                            : 'Select a brand',
                        items: controller.brands.toList(),
                        itemLabel: (BrandModel b) => b.name,
                        value: controller.brands.firstWhereOrNull(
                          (BrandModel b) => b.id == controller.brandId.value,
                        ),
                        onChanged: (BrandModel? brand) =>
                            controller.brandId.value = brand?.id,
                      ),
                    ),
                    AppTextField(
                      label: 'Product name',
                      controller: controller.nameController,
                      validator: controller.validateName,
                      isRequired: true,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField(
                      label: 'Model',
                      controller: controller.modelController,
                      hint: 'e.g. Shine 125',
                    ),
                    AppTextField(
                      label: 'Variant',
                      controller: controller.variantController,
                      hint: 'e.g. Drum / Disc',
                    ),
                    Obx(
                      () => AppDropdown<ProductCategory>(
                        label: 'Category',
                        items: ProductCategory.values,
                        itemLabel: (ProductCategory c) => c.label,
                        value: controller.category.value,
                        isRequired: true,
                        onChanged: (ProductCategory? value) {
                          if (value != null) {
                            controller.category.value = value;
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // Engine, gearbox and mileage only make sense for a vehicle.
                Obx(
                  () => controller.showsVehicleFields
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            AppSpacing.gapXxl,
                            _SectionTitle('Specification'),
                            AppFieldRow(
                              children: <Widget>[
                                AppTextField.integer(
                                  label: 'Engine (cc)',
                                  controller: controller.engineCcController,
                                  validator: controller.validateEngineCc,
                                  isRequired: false,
                                ),
                                AppDropdown<FuelType>(
                                  label: 'Fuel type',
                                  items: FuelType.values,
                                  itemLabel: (FuelType f) => f.label,
                                  value: controller.fuelType.value,
                                  onChanged: (FuelType? value) {
                                    if (value != null) {
                                      controller.fuelType.value = value;
                                    }
                                  },
                                ),
                                AppDropdown<TransmissionType>(
                                  label: 'Transmission',
                                  items: TransmissionType.values,
                                  itemLabel: (TransmissionType t) => t.label,
                                  value: controller.transmission.value,
                                  onChanged: (TransmissionType? value) {
                                    if (value != null) {
                                      controller.transmission.value = value;
                                    }
                                  },
                                ),
                                AppTextField.money(
                                  label: 'Mileage (kmpl)',
                                  controller: controller.mileageController,
                                  isRequired: false,
                                ),
                              ],
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                AppSpacing.gapXxl,
                _SectionTitle('Pricing'),
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.money(
                      label: 'Base price',
                      controller: controller.basePriceController,
                      validator: controller.validateBasePrice,
                      isRequired: false,
                      helper: 'Ex-showroom, before tax',
                    ),
                    AppTextField.money(
                      label: 'Selling price',
                      controller: controller.sellingPriceController,
                      validator: controller.validateSellingPrice,
                    ),
                    AppTextField.money(
                      label: 'Tax rate (%)',
                      controller: controller.taxRateController,
                      validator: controller.validateTaxRate,
                      isRequired: false,
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.integer(
                      label: 'Warranty (months)',
                      controller: controller.warrantyMonthsController,
                      validator: controller.validateWarrantyMonths,
                      isRequired: false,
                    ),
                    AppTextField.code(
                      label: 'HSN code',
                      controller: controller.hsnController,
                      isRequired: false,
                      maxLength: 10,
                    ),
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
                  ],
                ),
                AppSpacing.gapLg,
                AppTextField.multiline(
                  label: 'Description',
                  controller: controller.descriptionController,
                  maxLines: 3,
                ),

                AppSpacing.gapXxl,
                const _ColorsSection(),

                AppSpacing.gapXxl,
                Row(
                  children: <Widget>[
                    AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
                    const Spacer(),
                    Obx(
                      () => AppButton.primary(
                        label: controller.isEditing
                            ? 'Save changes'
                            : 'Create product',
                        isLoading: controller.isSubmitting.value,
                        onPressed: () async {
                          final ProductModel? saved = await controller.submit();
                          if (saved != null) {
                            Get.back<ProductModel>(result: saved);
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

/// Colour management.
///
/// Available only once the product exists: `product_colors.product_id` is NOT
/// NULL, so there is no parent to attach a colour to while the product is
/// still unsaved. Rather than silently dropping colours typed on a create
/// form, the section says so and appears properly on the next edit.
class _ColorsSection extends StatelessWidget {
  const _ColorsSection();

  @override
  Widget build(BuildContext context) {
    final ProductFormController controller = Get.find<ProductFormController>();

    if (!controller.isEditing) {
      return Row(
        children: <Widget>[
          Icon(
            Icons.palette_outlined,
            size: 18,
            color: Theme.of(context).hintColor,
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              'Save the product first, then add its colours here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Colours',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppButton.secondary(
              label: 'Add colour',
              icon: Icons.add,
              size: AppButtonSize.small,
              onPressed: () => Get.dialog<void>(
                _ColorDialog(controller: controller),
                barrierDismissible: false,
              ),
            ),
          ],
        ),
        AppSpacing.gapLg,
        Obx(
          () => controller.colors.isEmpty
              ? Text(
                  'No colours added yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final ProductColorModel color in controller.colors)
                      _ColorChip(color: color, controller: controller),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.color, required this.controller});

  final ProductColorModel color;
  final ProductFormController controller;

  @override
  Widget build(BuildContext context) => InputChip(
    avatar: CircleAvatar(backgroundColor: color.swatch),
    label: Text(color.colorName),
    // A retired colour stays visible but greyed: units in stock still point
    // at it, so hiding it would make their colour look missing.
    labelStyle: color.isActive
        ? null
        : TextStyle(
            color: Theme.of(context).disabledColor,
            decoration: TextDecoration.lineThrough,
          ),
    onPressed: () => controller.toggleColor(color),
    tooltip: color.isActive ? 'Retire this colour' : 'Restore this colour',
  );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.controller});

  final ProductFormController controller;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _hex = TextEditingController(text: '#');

  @override
  void dispose() {
    _name.dispose();
    _hex.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bool added = await widget.controller.addColor(
      name: _name.text,
      hex: _hex.text,
    );
    if (added) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Colour'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextField(
            label: 'Colour name',
            controller: _name,
            isRequired: true,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          AppSpacing.gapLg,
          AppTextField(
            label: 'Hex code',
            controller: _hex,
            isRequired: true,
            hint: '#1A73E8',
            maxLength: 7,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            // No margin: AppTextField already pads the suffix.
            suffix: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: ProductColorModel(
                  id: 'preview',
                  productId: 'preview',
                  colorName: 'preview',
                  hexCode: _hex.text,
                ).swatch,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
      Obx(
        () => AppButton.primary(
          label: 'Add',
          isLoading: widget.controller.isSavingColor.value,
          onPressed: _save,
        ),
      ),
    ],
  );
}
