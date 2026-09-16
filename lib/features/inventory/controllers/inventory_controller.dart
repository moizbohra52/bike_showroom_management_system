import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/inventory_repository.dart';
import 'package:bike_showroom_management_system/features/products/models/product_color_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the stock list for the active showroom.
class InventoryController extends ListController<InventoryModel> {
  InventoryController({required InventoryRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>[
          'stock_code',
          'chassis_number',
          'engine_number',
        ],
      );

  InventoryRepository get _repository => repository as InventoryRepository;

  final Rxn<InventoryStatus> statusFilter = Rxn<InventoryStatus>();
  final RxMap<InventoryStatus, int> counts = <InventoryStatus, int>{}.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadCounts());
  }

  /// The scope the summary tiles must count over.
  ///
  /// Read from the list's own params rather than from the session: the base
  /// controller leaves `showroomId` null for a super admin, who therefore sees
  /// every branch's stock. Counting the session's active branch instead would
  /// put single-branch totals above multi-branch rows.
  String? get countScopeShowroomId => params.value.showroomId;

  Future<void> loadCounts() async {
    try {
      counts.assignAll(await _repository.statusCounts(countScopeShowroomId));
    } on Object catch (e) {
      // A failed summary must not blank the list itself, which is the part
      // the user actually came for.
      AppSnackbar.fromException(e);
    }
  }

  void filterByStatus(InventoryStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter('status');
    } else {
      applyFilter(QueryFilter.equals('status', status.value));
    }
  }

  /// Moves a unit to another status through the server-side RPC.
  Future<void> adjust({
    required InventoryModel unit,
    required InventoryStatus newStatus,
    required String reason,
  }) async {
    if (!Get.find<SessionController>().can(AppPermissions.inventoryAdjust)) {
      AppSnackbar.error('You do not have permission to adjust stock.');
      return;
    }
    try {
      await _repository.adjustStatus(
        inventoryId: unit.id,
        newStatus: newStatus,
        reason: reason,
      );
      AppSnackbar.success('Stock updated to ${newStatus.label}.');
      await reload();
      await loadCounts();
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    }
  }
}

/// Owns the intake form for one unit.
class InventoryFormController extends GetxController {
  InventoryFormController({
    required this.inventoryRepository,
    required this.productRepository,
    InventoryModel? existing,
  }) : editing = existing;

  final InventoryRepository inventoryRepository;
  final ProductRepository productRepository;

  final InventoryModel? editing;

  bool get isEditing => editing != null;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController chassisController = TextEditingController();
  final TextEditingController engineController = TextEditingController();
  final TextEditingController modelYearController = TextEditingController();
  final TextEditingController purchasePriceController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  final Rxn<String> productId = Rxn<String>();
  final Rxn<String> colorId = Rxn<String>();
  final Rxn<DateTime> manufacturingDate = Rxn<DateTime>();
  final Rxn<DateTime> purchaseDate = Rxn<DateTime>();
  final Rx<InventoryStatus> status = InventoryStatus.available.obs;

  final RxList<ProductModel> products = <ProductModel>[].obs;
  final RxBool isLoadingProducts = false.obs;
  final RxBool isSubmitting = false.obs;

  /// Colours offered for the product currently selected. Empty until a product
  /// is chosen, because a colour belongs to a product, not to the catalogue.
  List<ProductColorModel> get availableColors {
    final String? id = productId.value;
    if (id == null) {
      return const <ProductColorModel>[];
    }
    for (final ProductModel product in products) {
      if (product.id == id) {
        return product.activeColors;
      }
    }
    return const <ProductColorModel>[];
  }

  @override
  void onInit() {
    super.onInit();

    final InventoryModel? source = editing;
    if (source != null) {
      chassisController.text = source.chassisNumber;
      engineController.text = source.engineNumber;
      modelYearController.text = source.modelYear?.toString() ?? '';
      purchasePriceController.text = source.purchasePrice.toStringAsFixed(2);
      locationController.text = source.location ?? '';
      notesController.text = source.notes ?? '';
      productId.value = source.productId;
      colorId.value = source.colorId;
      manufacturingDate.value = source.manufacturingDate;
      purchaseDate.value = source.purchaseDate;
      status.value = source.status;
    } else {
      purchaseDate.value = DateTime.now();
    }

    unawaited(_loadProducts());
  }

  Future<void> _loadProducts() async {
    isLoadingProducts.value = true;
    try {
      // Vehicles only: an accessory has no chassis number and therefore no
      // row of its own in `inventory`.
      products.assignAll(
        await productRepository.listSelectable(vehiclesOnly: true),
      );
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoadingProducts.value = false;
    }
  }

  /// Clears the colour when the product changes — a colour from the previous
  /// product would fail the foreign key, and silently keeping it would let the
  /// form show a colour the new model is not available in.
  void selectProduct(String? id) {
    if (productId.value != id) {
      colorId.value = null;
    }
    productId.value = id;
  }

  String? validateChassis(String? value) => AppValidators.chassisNumber(value);

  String? validateEngine(String? value) => AppValidators.engineNumber(value);

  String? validateModelYear(String? value) => AppValidators.modelYear(value);

  String? validatePurchasePrice(String? value) => AppValidators.amount(
    value,
    field: 'Purchase price',
    isRequired: false,
    allowZero: true,
  );

  Future<InventoryModel?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }
    if (productId.value == null) {
      AppSnackbar.error('Select the product this unit is.');
      return null;
    }

    final SessionController session = Get.find<SessionController>();
    final String permission = isEditing
        ? AppPermissions.inventoryEdit
        : AppPermissions.inventoryCreate;
    if (!session.can(permission)) {
      AppSnackbar.error('You do not have permission to do this.');
      return null;
    }

    final String? showroomId =
        editing?.showroomId ?? session.activeShowroomId.value;
    if (showroomId == null) {
      AppSnackbar.error('Select a showroom before adding stock.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'product_id': productId.value,
        'color_id': colorId.value,
        'chassis_number': chassisController.text.trim().toUpperCase(),
        'engine_number': engineController.text.trim().toUpperCase(),
        'model_year': int.tryParse(modelYearController.text.trim()),
        'manufacturing_date': DateUtil.toIsoDateOrNull(manufacturingDate.value),
        'purchase_date': DateUtil.toIsoDateOrNull(purchaseDate.value),
        'purchase_price':
            double.tryParse(purchasePriceController.text.trim()) ?? 0,
        'location': _orNull(locationController.text),
        'notes': _orNull(notesController.text),
      };

      if (isEditing) {
        // `status` is not in the payload: it moves only through
        // `adjust_inventory`, which validates the transition and records why.
        final InventoryModel saved = await inventoryRepository.update(
          editing!.id,
          payload,
          expectedRevision: editing!.revision,
        );
        AppSnackbar.success('Stock updated.');
        return saved;
      }

      final InventoryModel saved = await inventoryRepository
          .create(<String, Object?>{
            ...payload,
            'showroom_id': showroomId,
            'stock_code': await inventoryRepository.nextStockCode(showroomId),
            'status': status.value.value,
          });
      AppSnackbar.success('Stock added as ${saved.stockCode}.');
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
    modelYearController.dispose();
    purchasePriceController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.onClose();
  }
}
