import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/products/models/brand_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_color_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/products/repositories/brand_repository.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the product catalogue list.
///
/// Not showroom-scoped: the catalogue is shared, and a product a branch does
/// not currently stock still has to be findable so a unit of it can be taken
/// into inventory.
class ProductController extends ListController<ProductModel> {
  ProductController({required ProductRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['name', 'model', 'variant', 'hsn_code'],
      );

  @override
  bool get scopeToActiveShowroom => false;

  ProductRepository get _repository => repository as ProductRepository;

  /// Category currently filtered on, or null for all.
  final Rxn<ProductCategory> categoryFilter = Rxn<ProductCategory>();

  void filterByCategory(ProductCategory? category) {
    categoryFilter.value = category;
    if (category == null) {
      removeFilter('category');
    } else {
      applyFilter(QueryFilter.equals('category', category.value));
    }
  }

  Future<void> toggleStatus(ProductModel product) async {
    final RecordStatus next = product.isActive
        ? RecordStatus.inactive
        : RecordStatus.active;
    try {
      await _repository.update(product.id, <String, Object?>{
        'status': next.value,
      });
      AppSnackbar.success(
        next.isActive ? 'Product activated.' : 'Product deactivated.',
      );
      await reload();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }

  Future<void> deleteProduct(ProductModel product) async {
    try {
      await _repository.delete(product.id);
      AppSnackbar.success('Product removed from the catalogue.');
      await reload();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }
}

/// Owns the create/edit form for a single product, including its colours.
class ProductFormController extends GetxController {
  ProductFormController({
    required this.productRepository,
    required this.brandRepository,
    ProductModel? existing,
  }) : editing = existing;

  final ProductRepository productRepository;
  final BrandRepository brandRepository;

  /// Null when creating.
  final ProductModel? editing;

  bool get isEditing => editing != null;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController variantController = TextEditingController();
  final TextEditingController engineCcController = TextEditingController();
  final TextEditingController mileageController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController basePriceController = TextEditingController();
  final TextEditingController sellingPriceController = TextEditingController();
  final TextEditingController taxRateController = TextEditingController();
  final TextEditingController warrantyMonthsController =
      TextEditingController();
  final TextEditingController hsnController = TextEditingController();

  final Rxn<String> brandId = Rxn<String>();
  final Rx<ProductCategory> category = ProductCategory.motorcycle.obs;
  final Rx<FuelType> fuelType = FuelType.petrol.obs;
  final Rx<TransmissionType> transmission = TransmissionType.manual.obs;
  final Rx<RecordStatus> status = RecordStatus.active.obs;

  final RxList<BrandModel> brands = <BrandModel>[].obs;
  final RxList<ProductColorModel> colors = <ProductColorModel>[].obs;

  final RxBool isSubmitting = false.obs;
  final RxBool isLoadingBrands = false.obs;
  final RxBool isSavingColor = false.obs;

  /// Only a serialised vehicle has an engine, a gearbox and a mileage figure.
  /// Hiding those fields for an accessory keeps a form that would otherwise
  /// ask a parts clerk for the transmission of a helmet.
  bool get showsVehicleFields => category.value.isSerialisedVehicle;

  @override
  void onInit() {
    super.onInit();

    final ProductModel? source = editing;
    if (source != null) {
      nameController.text = source.name;
      modelController.text = source.model ?? '';
      variantController.text = source.variant ?? '';
      engineCcController.text = source.engineCc?.toString() ?? '';
      mileageController.text = source.mileage?.toString() ?? '';
      descriptionController.text = source.description ?? '';
      basePriceController.text = source.basePrice.toStringAsFixed(2);
      sellingPriceController.text = source.sellingPrice.toStringAsFixed(2);
      taxRateController.text = source.taxRate.toStringAsFixed(2);
      warrantyMonthsController.text = source.warrantyMonths.toString();
      hsnController.text = source.hsnCode ?? '';
      brandId.value = source.brandId;
      category.value = source.category;
      fuelType.value = source.fuelType;
      transmission.value = source.transmission;
      status.value = source.status;
      colors.assignAll(source.colors);
    } else {
      taxRateController.text = '18.00';
      warrantyMonthsController.text = '24';
    }

    unawaited(_loadBrands());
  }

  Future<void> _loadBrands() async {
    isLoadingBrands.value = true;
    try {
      brands.assignAll(await brandRepository.listActive());
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoadingBrands.value = false;
    }
  }

  // ------------------------------------------------------------ validation

  String? validateName(String? value) =>
      AppValidators.name(value, field: 'Product name');

  String? validateSellingPrice(String? value) =>
      AppValidators.amount(value, field: 'Selling price');

  String? validateBasePrice(String? value) =>
      AppValidators.amount(value, field: 'Base price', isRequired: false);

  String? validateTaxRate(String? value) => AppValidators.taxRate(value);

  String? validateEngineCc(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final int? cc = int.tryParse(value.trim());
    if (cc == null || cc < 0 || cc > 5000) {
      return 'Enter a displacement between 0 and 5000 cc.';
    }
    return null;
  }

  String? validateWarrantyMonths(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final int? months = int.tryParse(value.trim());
    if (months == null || months < 0 || months > 240) {
      return 'Enter a warranty between 0 and 240 months.';
    }
    return null;
  }

  // ---------------------------------------------------------------- colours

  /// Adds a colour to the product being edited.
  ///
  /// Only available once the product exists, because `product_colors.
  /// product_id` is NOT NULL — there is nothing to attach a colour to until
  /// the parent row has been inserted.
  Future<bool> addColor({required String name, required String hex}) async {
    final ProductModel? source = editing;
    if (source == null) {
      AppSnackbar.error('Save the product first, then add its colours.');
      return false;
    }

    final String? nameError = AppValidators.required(
      name,
      field: 'Colour name',
    );
    if (nameError != null) {
      AppSnackbar.error(nameError);
      return false;
    }
    final String? hexError = AppValidators.hexColor(hex);
    if (hexError != null) {
      AppSnackbar.error(hexError);
      return false;
    }

    isSavingColor.value = true;
    try {
      colors.add(
        await productRepository.addColor(
          productId: source.id,
          colorName: name,
          hexCode: hex,
        ),
      );
      AppSnackbar.success('Colour added.');
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isSavingColor.value = false;
    }
  }

  Future<void> toggleColor(ProductColorModel color) async {
    try {
      final ProductColorModel updated = await productRepository.setColorActive(
        colorId: color.id,
        isActive: !color.isActive,
      );
      final int index = colors.indexWhere(
        (ProductColorModel c) => c.id == color.id,
      );
      if (index >= 0) {
        colors[index] = updated;
      }
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }

  // ----------------------------------------------------------------- submit

  Future<ProductModel?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }

    final String permission = isEditing
        ? AppPermissions.productsEdit
        : AppPermissions.productsCreate;
    if (!Get.find<SessionController>().can(permission)) {
      AppSnackbar.error('You do not have permission to do this.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final bool vehicle = category.value.isSerialisedVehicle;

      final Map<String, Object?> payload = <String, Object?>{
        'brand_id': brandId.value,
        'name': nameController.text.trim(),
        'model': _orNull(modelController.text),
        'variant': _orNull(variantController.text),
        'category': category.value.value,
        // Cleared rather than carried over when the category changes away from
        // a vehicle: a spare part with a transmission recorded against it
        // would show nonsense on every quotation it appeared on.
        'engine_cc': vehicle ? _intOrNull(engineCcController.text) : null,
        'fuel_type': fuelType.value.value,
        'transmission': vehicle
            ? transmission.value.value
            : TransmissionType.manual.value,
        'mileage': vehicle ? _doubleOrNull(mileageController.text) : null,
        'description': _orNull(descriptionController.text),
        'base_price': _doubleOrNull(basePriceController.text) ?? 0,
        'selling_price': _doubleOrNull(sellingPriceController.text) ?? 0,
        'tax_rate': _doubleOrNull(taxRateController.text) ?? 18,
        'warranty_months': _intOrNull(warrantyMonthsController.text) ?? 24,
        'hsn_code': _orNull(hsnController.text),
        'status': status.value.value,
      };

      // `engine_cc` and `mileage` are nulled deliberately above, so they must
      // survive buildWritePayload's null-stripping — otherwise switching a
      // product from motorcycle to accessory would leave the old values in
      // place instead of clearing them.
      final Map<String, Object?> body = buildWritePayload(
        payload,
        explicitNulls: const <String>{'engine_cc', 'mileage', 'brand_id'},
      );

      final ProductModel saved = isEditing
          ? await productRepository.update(
              editing!.id,
              body,
              expectedRevision: editing!.revision,
            )
          : await productRepository.create(body);

      AppSnackbar.success(isEditing ? 'Product updated.' : 'Product created.');
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

  int? _intOrNull(String value) => int.tryParse(value.trim());

  double? _doubleOrNull(String value) => double.tryParse(value.trim());

  @override
  void onClose() {
    nameController.dispose();
    modelController.dispose();
    variantController.dispose();
    engineCcController.dispose();
    mileageController.dispose();
    descriptionController.dispose();
    basePriceController.dispose();
    sellingPriceController.dispose();
    taxRateController.dispose();
    warrantyMonthsController.dispose();
    hsnController.dispose();
    super.onClose();
  }
}
