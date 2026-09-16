import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_item_model.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_model.dart';
import 'package:bike_showroom_management_system/features/purchases/models/supplier_model.dart';
import 'package:bike_showroom_management_system/features/purchases/repositories/purchase_repository.dart';
import 'package:bike_showroom_management_system/features/purchases/repositories/supplier_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the purchase list for the active showroom.
class PurchaseController extends ListController<PurchaseModel> {
  PurchaseController({required PurchaseRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['purchase_number', 'supplier_invoice_no'],
      );

  final Rxn<PurchaseStatus> statusFilter = Rxn<PurchaseStatus>();

  void filterByStatus(PurchaseStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter(DbColumns.status);
    } else {
      applyFilter(QueryFilter.equals(DbColumns.status, status.value));
    }
  }

  void filterByDateRange(DateRange? range) =>
      setDateRange(range, dateColumn: 'purchase_date');

  /// Orders still awaiting delivery — what a stores clerk works from.
  void showPendingReceipt() {
    statusFilter.value = null;
    params.value = params.value
        .withFilter(
          QueryFilter.inList('status', <String>[
            PurchaseStatus.ordered.value,
            PurchaseStatus.partiallyReceived.value,
          ]),
        )
        .resetPage();
    reload();
  }
}

/// One line the user is assembling on a purchase order.
class PurchaseLineDraft {
  PurchaseLineDraft({
    required this.product,
    required this.unitCost,
    required this.taxRate,
    this.quantity = 1,
  });

  final ProductModel product;
  double unitCost;
  double taxRate;
  int quantity;

  /// Purchases price per line, not per unit: the consignment is ordered in
  /// quantity and only becomes individual machines on receipt.
  LineAmounts get amounts => MoneyUtil.computeLine(
    quantity: quantity,
    unitPrice: unitCost,
    taxRate: taxRate,
  );

  Map<String, Object?> toPayload() => <String, Object?>{
    'product_id': product.id,
    'description': product.displayName,
    'quantity': quantity,
    'unit_cost': unitCost,
    'tax_rate': taxRate,
  };
}

/// Assembles a purchase order and submits it to
/// `create_purchase_transaction`.
class PurchaseCreateController extends GetxController {
  PurchaseCreateController({
    required this.purchaseRepository,
    required this.supplierRepository,
    required this.productRepository,
  });

  final PurchaseRepository purchaseRepository;
  final SupplierRepository supplierRepository;
  final ProductRepository productRepository;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final Rxn<String> supplierId = Rxn<String>();
  final Rxn<DateTime> purchaseDate = Rxn<DateTime>(DateTime.now());
  final RxList<PurchaseLineDraft> lines = <PurchaseLineDraft>[].obs;

  final TextEditingController supplierInvoiceController =
      TextEditingController();
  final TextEditingController discountController = TextEditingController();
  final TextEditingController otherChargesController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  final RxList<SupplierModel> suppliers = <SupplierModel>[].obs;
  final RxList<ProductModel> products = <ProductModel>[].obs;

  final RxBool isLoadingOptions = false.obs;
  final RxBool isSubmitting = false.obs;

  String? get showroomId =>
      Get.find<SessionController>().activeShowroomId.value;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadOptions());
  }

  Future<void> loadOptions() async {
    isLoadingOptions.value = true;
    try {
      suppliers.assignAll(await supplierRepository.listActive());
      // Vehicles only: the receiving step creates one `inventory` row per
      // machine, which an accessory has no chassis number for.
      products.assignAll(
        await productRepository.listSelectable(vehiclesOnly: true),
      );
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoadingOptions.value = false;
    }
  }

  /// Products not already on this order. The same model ordered twice belongs
  /// on one line with a quantity of two.
  List<ProductModel> get selectableProducts {
    final Set<String> taken = lines
        .map((PurchaseLineDraft line) => line.product.id)
        .toSet();
    return products
        .where((ProductModel p) => !taken.contains(p.id))
        .toList(growable: false);
  }

  void addLine(ProductModel product) {
    lines.add(
      PurchaseLineDraft(
        product: product,
        // Seeded from the catalogue's cost price, which is the usual figure;
        // the supplier's actual invoice may differ and is editable.
        unitCost: product.basePrice,
        taxRate: product.taxRate,
      ),
    );
    lines.refresh();
  }

  void removeLine(PurchaseLineDraft line) {
    lines.remove(line);
    lines.refresh();
  }

  void updateLine(PurchaseLineDraft line, {double? unitCost, int? quantity}) {
    if (unitCost != null) {
      line.unitCost = unitCost;
    }
    if (quantity != null) {
      line.quantity = quantity;
    }
    lines.refresh();
  }

  DocumentAmounts get totals => MoneyUtil.computeDocument(
    lines: lines.map((PurchaseLineDraft line) => line.amounts).toList(),
    documentDiscountAmount: _numberOf(discountController),
    otherCharges: _numberOf(otherChargesController),
  );

  String? validateDiscount(String? value) =>
      AppValidators.amount(value, isRequired: false, allowZero: true);

  String? get blockingIssue {
    if (supplierId.value == null) {
      return 'Select a supplier.';
    }
    if (lines.isEmpty) {
      return 'Add at least one product.';
    }
    if (lines.any((PurchaseLineDraft l) => l.quantity < 1)) {
      return 'Every line needs a quantity of at least one.';
    }
    return null;
  }

  Future<String?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }
    final String? issue = blockingIssue;
    if (issue != null) {
      AppSnackbar.error(issue);
      return null;
    }
    if (!Get.find<SessionController>().can(AppPermissions.purchasesCreate)) {
      AppSnackbar.error('You do not have permission to create a purchase.');
      return null;
    }
    final String? id = showroomId;
    if (id == null) {
      AppSnackbar.error('Select a showroom before raising a purchase.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final String purchaseId = await purchaseRepository
          .createPurchase(<String, Object?>{
            'showroom_id': id,
            'supplier_id': supplierId.value,
            'purchase_date': DateUtil.toIsoDateOrNull(purchaseDate.value),
            'items': lines
                .map((PurchaseLineDraft line) => line.toPayload())
                .toList(growable: false),
            'discount': _numberOf(discountController),
            'other_charges': _numberOf(otherChargesController),
            if (supplierInvoiceController.text.trim().isNotEmpty)
              'supplier_invoice_no': supplierInvoiceController.text.trim(),
            if (notesController.text.trim().isNotEmpty)
              'notes': notesController.text.trim(),
          });
      AppSnackbar.success('Purchase order raised.');
      return purchaseId;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  double _numberOf(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  @override
  void onClose() {
    supplierInvoiceController.dispose();
    discountController.dispose();
    otherChargesController.dispose();
    notesController.dispose();
    super.onClose();
  }
}

/// One physical machine being taken into stock from a consignment.
class ReceivedUnitDraft {
  ReceivedUnitDraft({required this.productId, required this.productLabel});

  final String productId;
  final String productLabel;

  final TextEditingController chassis = TextEditingController();
  final TextEditingController engine = TextEditingController();

  bool get isComplete =>
      AppValidators.chassisNumber(chassis.text) == null &&
      AppValidators.engineNumber(engine.text) == null;

  Map<String, Object?> toPayload({required double unitCost}) =>
      <String, Object?>{
        'product_id': productId,
        'chassis_number': chassis.text.trim().toUpperCase(),
        'engine_number': engine.text.trim().toUpperCase(),
        'purchase_price': unitCost,
      };

  void dispose() {
    chassis.dispose();
    engine.dispose();
  }
}

/// Loads one purchase and owns the receiving step.
class PurchaseDetailsController extends GetxController {
  PurchaseDetailsController({
    required this.purchaseRepository,
    required this.purchase,
  });

  final PurchaseRepository purchaseRepository;

  /// The list's row, shown while the full record loads.
  final PurchaseModel purchase;

  late final Rx<PurchaseModel> detail = purchase.obs;

  /// One entry per expected machine, built from the order's lines.
  final RxList<ReceivedUnitDraft> units = <ReceivedUnitDraft>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isReceiving = false.obs;
  final Rxn<AppException> error = Rxn<AppException>();

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final PurchaseModel loaded = await purchaseRepository.getDetail(
        purchase.id,
      );
      detail.value = loaded;
      if (loaded.canReceive) {
        _buildUnitDrafts(loaded);
      }
    } on Object catch (e, stackTrace) {
      final AppException mapped = ErrorMapper.map(e, stackTrace);
      error.value = mapped;
      AppSnackbar.fromException(mapped);
    } finally {
      isLoading.value = false;
    }
  }

  /// Expands each line's quantity into that many chassis/engine entries.
  ///
  /// A line for three bikes needs three rows: `receive_purchase` creates one
  /// `inventory` row per machine, each with its own identifiers.
  void _buildUnitDrafts(PurchaseModel loaded) {
    for (final ReceivedUnitDraft draft in units) {
      draft.dispose();
    }
    final List<ReceivedUnitDraft> drafts = <ReceivedUnitDraft>[];
    for (final PurchaseItemModel item in loaded.items) {
      for (int i = 0; i < item.quantity.round(); i++) {
        drafts.add(
          ReceivedUnitDraft(
            productId: item.productId,
            productLabel: item.label,
          ),
        );
      }
    }
    units.assignAll(drafts);
  }

  /// The per-unit cost to record against each machine, taken from its line.
  double unitCostFor(String productId) {
    for (final PurchaseItemModel item in detail.value.items) {
      if (item.productId == productId) {
        return item.unitCost;
      }
    }
    return 0;
  }

  int get completeUnitCount =>
      units.where((ReceivedUnitDraft u) => u.isComplete).length;

  /// Receives the consignment.
  ///
  /// Every unit must be identified before anything is created: a partial
  /// receipt would mark the whole order RECEIVED server-side while leaving
  /// some machines unrecorded, and there would be no way to add them later
  /// through this screen.
  Future<bool> receive() async {
    // The RPC checks `inventory.create` rather than a purchases right — the
    // act being authorised is creating stock.
    if (!Get.find<SessionController>().can(AppPermissions.inventoryCreate)) {
      AppSnackbar.error('You do not have permission to take stock in.');
      return false;
    }
    if (units.isEmpty) {
      AppSnackbar.error('This order has no lines to receive.');
      return false;
    }
    if (completeUnitCount != units.length) {
      AppSnackbar.error(
        'Enter a valid chassis and engine number for all '
        '${units.length} machines.',
      );
      return false;
    }

    isReceiving.value = true;
    try {
      final int created = await purchaseRepository
          .receivePurchase(<String, Object?>{
            'purchase_id': detail.value.id,
            'units': units
                .map(
                  (ReceivedUnitDraft u) =>
                      u.toPayload(unitCost: unitCostFor(u.productId)),
                )
                .toList(growable: false),
          });
      AppSnackbar.success('$created unit(s) taken into stock.');
      await load();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    } finally {
      isReceiving.value = false;
    }
  }

  @override
  void onClose() {
    for (final ReceivedUnitDraft draft in units) {
      draft.dispose();
    }
    super.onClose();
  }
}
