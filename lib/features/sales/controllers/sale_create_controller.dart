import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:bike_showroom_management_system/features/customers/repositories/customer_repository.dart';
import 'package:bike_showroom_management_system/features/finance/models/finance_company_model.dart';
import 'package:bike_showroom_management_system/features/finance/repositories/finance_company_repository.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/inventory_repository.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_model.dart';
import 'package:bike_showroom_management_system/features/sales/repositories/sale_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// One line the user is assembling, before the server prices it.
///
/// The price and tax rate start from the catalogue, which is also where the
/// server takes them from when the client omits them — so the figures on
/// screen match what will actually be charged, while the server remains the
/// authority.
class SaleLineDraft {
  SaleLineDraft({
    required this.unit,
    required this.unitPrice,
    required this.taxRate,
    this.quantity = 1,
    this.discount = 0,
  });

  final InventoryModel unit;
  double unitPrice;
  double taxRate;
  double quantity;
  double discount;

  LineAmounts get amounts => MoneyUtil.computeLine(
    quantity: quantity,
    unitPrice: unitPrice,
    discountAmount: discount,
    taxRate: taxRate,
  );

  /// The shape `create_sale_transaction` expects for one element of `items`.
  Map<String, Object?> toPayload() => <String, Object?>{
    'inventory_id': unit.id,
    'quantity': quantity,
    'unit_price': unitPrice,
    'discount': discount,
    'tax_rate': taxRate,
  };
}

/// Assembles a sale and submits it to `create_sale_transaction`.
///
/// Every total shown here is a **preview**. The server recomputes all of it
/// from the catalogue, so a tampered form cannot set its own price; the
/// preview exists so the salesperson can see the figure before committing,
/// not so the client can decide it.
class SaleCreateController extends GetxController {
  SaleCreateController({
    required this.saleRepository,
    required this.customerRepository,
    required this.inventoryRepository,
    required this.productRepository,
    required this.financeCompanyRepository,
  });

  final SaleRepository saleRepository;
  final CustomerRepository customerRepository;
  final InventoryRepository inventoryRepository;
  final ProductRepository productRepository;
  final FinanceCompanyRepository financeCompanyRepository;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // ------------------------------------------------------------ selections

  final Rxn<String> customerId = Rxn<String>();
  final Rx<SaleType> saleType = SaleType.cash.obs;
  final Rxn<DateTime> saleDate = Rxn<DateTime>(DateTime.now());
  final Rxn<DateTime> deliveryDate = Rxn<DateTime>();
  final RxList<SaleLineDraft> lines = <SaleLineDraft>[].obs;

  final TextEditingController discountController = TextEditingController();
  final TextEditingController otherChargesController = TextEditingController();
  final TextEditingController paidAmountController = TextEditingController();
  final TextEditingController paymentReferenceController =
      TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final Rx<PaymentMethod> paymentMethod = PaymentMethod.cash.obs;

  // --------------------------------------------------------- finance block

  final Rxn<String> financeCompanyId = Rxn<String>();
  final TextEditingController downPaymentController = TextEditingController();
  final TextEditingController interestRateController = TextEditingController();
  final TextEditingController tenureController = TextEditingController();
  final TextEditingController processingFeeController = TextEditingController();
  final Rx<InterestType> interestType = InterestType.reducing.obs;
  final RxDouble emiPreview = 0.0.obs;
  final RxBool isCalculatingEmi = false.obs;

  // ------------------------------------------------------------- reference

  final RxList<CustomerModel> customers = <CustomerModel>[].obs;
  final RxList<InventoryModel> availableUnits = <InventoryModel>[].obs;
  final RxList<ProductModel> products = <ProductModel>[].obs;
  final RxList<FinanceCompanyModel> financeCompanies =
      <FinanceCompanyModel>[].obs;

  final RxBool isLoadingOptions = false.obs;
  final RxBool isSubmitting = false.obs;

  bool get isFinanced => saleType.value == SaleType.finance;

  String? get showroomId =>
      Get.find<SessionController>().activeShowroomId.value;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadOptions());
  }

  Future<void> loadOptions() async {
    final String? id = showroomId;
    if (id == null) {
      AppSnackbar.error('Select a showroom before creating a sale.');
      return;
    }

    isLoadingOptions.value = true;
    try {
      customers.assignAll(await customerRepository.listSelectable(id));
      availableUnits.assignAll(
        await inventoryRepository.listAllocatable(showroomId: id),
      );
      products.assignAll(
        await productRepository.listSelectable(vehiclesOnly: true),
      );
      financeCompanies.assignAll(await financeCompanyRepository.listActive());
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoadingOptions.value = false;
    }
  }

  // ----------------------------------------------------------------- lines

  /// Units not already on this sale.
  ///
  /// The same bike cannot be sold twice on one document, and the server would
  /// reject it on the second pass through the item loop — better to not offer
  /// it than to explain the error afterwards.
  List<InventoryModel> get selectableUnits {
    final Set<String> taken = lines
        .map((SaleLineDraft line) => line.unit.id)
        .toSet();
    return availableUnits
        .where((InventoryModel unit) => !taken.contains(unit.id))
        .toList(growable: false);
  }

  void addLine(InventoryModel unit) {
    final ProductModel? product = _productFor(unit.productId);
    lines.add(
      SaleLineDraft(
        unit: unit,
        // Falls back to the unit's purchase price only if the catalogue has
        // no selling price, which would otherwise quote the customer zero.
        unitPrice: product?.sellingPrice ?? unit.purchasePrice,
        taxRate: product?.taxRate ?? 18,
      ),
    );
    lines.refresh();
    _syncFinanceAmount();
  }

  void removeLine(SaleLineDraft line) {
    lines.remove(line);
    lines.refresh();
    _syncFinanceAmount();
  }

  void updateLine(
    SaleLineDraft line, {
    double? unitPrice,
    double? discount,
    double? quantity,
  }) {
    if (unitPrice != null) {
      line.unitPrice = unitPrice;
    }
    if (discount != null) {
      line.discount = discount;
    }
    if (quantity != null) {
      line.quantity = quantity;
    }
    lines.refresh();
    _syncFinanceAmount();
  }

  ProductModel? _productFor(String productId) {
    for (final ProductModel product in products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- totals

  DocumentAmounts get totals => MoneyUtil.computeDocument(
    lines: lines.map((SaleLineDraft line) => line.amounts).toList(),
    documentDiscountAmount: _numberOf(discountController),
    otherCharges: _numberOf(otherChargesController),
  );

  double get paidAmount => _numberOf(paidAmountController);

  double get outstanding {
    final double due = totals.totalValue - paidAmount;
    return due < 0 ? 0 : due;
  }

  /// Combined line and document discount as a share of the pre-discount value.
  ///
  /// `create_sale_transaction` refuses a sale above the showroom's threshold
  /// unless the user holds `sales.approve` or `sales.discount`; showing the
  /// figure lets the salesperson see they are about to need it.
  double get discountPercentage {
    final double subtotal = totals.subtotalValue;
    if (subtotal <= 0) {
      return 0;
    }
    return totals.discountValue / subtotal * 100;
  }

  // --------------------------------------------------------------- finance

  /// Keeps the financed amount in step with the sale total.
  ///
  /// The loan is for what is left after the down payment, so changing a line
  /// must move it; leaving a stale figure would create a schedule for an
  /// amount the customer is not borrowing.
  void _syncFinanceAmount() {
    if (isFinanced) {
      unawaited(recalculateEmi());
    }
  }

  double get financedAmount {
    final double down = _numberOf(downPaymentController);
    final double amount = totals.totalValue - down;
    return amount < 0 ? 0 : amount;
  }

  /// Asks the database for the EMI rather than reimplementing the formula.
  ///
  /// `calculate_emi` is the same function `create_loan_with_schedule` uses, so
  /// the preview cannot drift from the schedule that will actually be
  /// generated — which a second implementation in Dart eventually would,
  /// particularly for the FLAT interest case.
  Future<void> recalculateEmi() async {
    final double principal = financedAmount;
    final double rate = _numberOf(interestRateController);
    final int tenure = int.tryParse(tenureController.text.trim()) ?? 0;

    if (principal <= 0 || tenure <= 0) {
      emiPreview.value = 0;
      return;
    }

    isCalculatingEmi.value = true;
    try {
      final Object? result = await saleRepository
          .rpc('calculate_emi', <String, Object?>{
            'p_principal': principal,
            'p_annual_rate': rate,
            'p_tenure_months': tenure,
            'p_interest_type': interestType.value.value,
          });
      emiPreview.value = result is num ? result.toDouble() : 0;
    } on Object {
      // A failed preview must not block the sale; the schedule is built
      // server-side either way.
      emiPreview.value = 0;
    } finally {
      isCalculatingEmi.value = false;
    }
  }

  // ------------------------------------------------------------ validation

  String? validateDiscount(String? value) =>
      AppValidators.amount(value, isRequired: false, allowZero: true);

  String? validatePaidAmount(String? value) {
    final String? base = AppValidators.amount(
      value,
      field: 'Amount received',
      isRequired: false,
      allowZero: true,
    );
    if (base != null) {
      return base;
    }
    final double amount = double.tryParse((value ?? '').trim()) ?? 0;
    if (amount > totals.totalValue + 0.01) {
      return 'Cannot exceed the sale total.';
    }
    return null;
  }

  String? validateInterestRate(String? value) =>
      AppValidators.interestRate(value);

  String? validateTenure(String? value) => AppValidators.tenureMonths(value);

  /// What is still missing before the sale can be submitted, or null when
  /// ready. Surfaced next to the button so the reason is visible rather than
  /// only discovered on tapping it.
  String? get blockingIssue {
    if (customerId.value == null) {
      return 'Select a customer.';
    }
    if (lines.isEmpty) {
      return 'Add at least one vehicle.';
    }
    if (isFinanced && financeCompanyId.value == null) {
      return 'Select a finance company.';
    }
    if (isFinanced && (int.tryParse(tenureController.text.trim()) ?? 0) <= 0) {
      return 'Enter the loan tenure.';
    }
    if (paymentMethod.value != PaymentMethod.cash &&
        paymentMethod.value != PaymentMethod.mixed &&
        paidAmount > 0 &&
        paymentReferenceController.text.trim().isEmpty) {
      // `record_payment` refuses a non-cash tender with no reference, since
      // it could never be reconciled against a bank statement.
      return 'A reference number is required for a '
          '${paymentMethod.value.label.toLowerCase()} payment.';
    }
    return null;
  }

  // ---------------------------------------------------------------- submit

  Future<SaleTransactionResult?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }

    final String? issue = blockingIssue;
    if (issue != null) {
      AppSnackbar.error(issue);
      return null;
    }

    if (!Get.find<SessionController>().can(AppPermissions.salesCreate)) {
      AppSnackbar.error('You do not have permission to create a sale.');
      return null;
    }

    final String? id = showroomId;
    if (id == null) {
      AppSnackbar.error('Select a showroom before creating a sale.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'showroom_id': id,
        'customer_id': customerId.value,
        'sale_date': DateUtil.toIsoDateOrNull(saleDate.value),
        'sale_type': saleType.value.value,
        'items': lines
            .map((SaleLineDraft line) => line.toPayload())
            .toList(growable: false),
        'discount': _numberOf(discountController),
        'other_charges': _numberOf(otherChargesController),
        'paid_amount': paidAmount,
        'payment_method': paymentMethod.value.value,
        if (paymentReferenceController.text.trim().isNotEmpty)
          'payment_reference': paymentReferenceController.text.trim(),
        if (deliveryDate.value != null)
          'delivery_date': DateUtil.toIsoDateOrNull(deliveryDate.value),
        if (notesController.text.trim().isNotEmpty)
          'notes': notesController.text.trim(),
        if (isFinanced)
          'loan': <String, Object?>{
            'finance_company_id': financeCompanyId.value,
            // The full sale value: the function subtracts the down payment
            // itself to arrive at the financed principal.
            'loan_amount': totals.totalValue,
            'down_payment': _numberOf(downPaymentController),
            'interest_rate': _numberOf(interestRateController),
            'interest_type': interestType.value.value,
            'tenure_months': int.tryParse(tenureController.text.trim()) ?? 0,
            'processing_fee': _numberOf(processingFeeController),
            'start_date': DateUtil.toIsoDateOrNull(saleDate.value),
          },
      };

      final SaleTransactionResult result = await saleRepository.createSale(
        payload,
      );
      AppSnackbar.success('Sale ${result.saleNumber} created.');
      return result;
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
    discountController.dispose();
    otherChargesController.dispose();
    paidAmountController.dispose();
    paymentReferenceController.dispose();
    notesController.dispose();
    downPaymentController.dispose();
    interestRateController.dispose();
    tenureController.dispose();
    processingFeeController.dispose();
    super.onClose();
  }
}
