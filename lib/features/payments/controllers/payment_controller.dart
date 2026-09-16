import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_snackbar.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';
import 'package:bike_showroom_management_system/features/billing/repositories/invoice_repository.dart';
import 'package:bike_showroom_management_system/features/payments/models/payment_model.dart';
import 'package:bike_showroom_management_system/features/payments/repositories/payment_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Drives the payments list for the active showroom.
class PaymentController extends ListController<PaymentModel> {
  PaymentController({required PaymentRepository repository})
    : super(
        repository: repository,
        searchColumns: const <String>['payment_number', 'reference_number'],
      );

  PaymentRepository get _repository => repository as PaymentRepository;

  final Rxn<PaymentMethod> methodFilter = Rxn<PaymentMethod>();
  final Rxn<PaymentStatus> statusFilter = Rxn<PaymentStatus>();

  void filterByMethod(PaymentMethod? method) {
    methodFilter.value = method;
    if (method == null) {
      removeFilter('payment_method');
    } else {
      applyFilter(QueryFilter.equals('payment_method', method.value));
    }
  }

  void filterByStatus(PaymentStatus? status) {
    statusFilter.value = status;
    if (status == null) {
      removeFilter(DbColumns.status);
    } else {
      applyFilter(QueryFilter.equals(DbColumns.status, status.value));
    }
  }

  void filterByDateRange(DateRange? range) =>
      setDateRange(range, dateColumn: 'payment_date');

  /// Reverses a payment through the RPC.
  ///
  /// The original row stays: the customer holds a receipt for it, so the
  /// ledger must show the receipt and its contra rather than pretending
  /// neither happened.
  Future<bool> reverse({
    required PaymentModel payment,
    required String reason,
  }) async {
    if (!Get.find<SessionController>().can(AppPermissions.paymentsRefund)) {
      AppSnackbar.error('You do not have permission to reverse a payment.');
      return false;
    }
    try {
      await _repository.reversePayment(paymentId: payment.id, reason: reason);
      AppSnackbar.success('Payment ${payment.paymentNumber} reversed.');
      await reload();
      return true;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return false;
    }
  }
}

/// Collects a payment against an invoice and submits it to `record_payment`.
class PaymentFormController extends GetxController {
  PaymentFormController({
    required this.paymentRepository,
    required this.invoiceRepository,
    this.presetInvoice,
  });

  final PaymentRepository paymentRepository;
  final InvoiceRepository invoiceRepository;

  /// Set when the form was opened from an invoice, so it is pre-selected.
  final InvoiceModel? presetInvoice;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController referenceController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  final Rxn<String> invoiceId = Rxn<String>();
  final Rx<PaymentMethod> paymentMethod = PaymentMethod.cash.obs;
  final Rxn<DateTime> paymentDate = Rxn<DateTime>(DateTime.now());

  final RxList<InvoiceModel> openInvoices = <InvoiceModel>[].obs;
  final RxBool isLoadingInvoices = false.obs;
  final RxBool isSubmitting = false.obs;

  String? get showroomId =>
      Get.find<SessionController>().activeShowroomId.value;

  /// The invoice currently selected, when it is one of the loaded options.
  InvoiceModel? get selectedInvoice {
    final String? id = invoiceId.value;
    if (id == null) {
      return null;
    }
    for (final InvoiceModel invoice in openInvoices) {
      if (invoice.id == id) {
        return invoice;
      }
    }
    return presetInvoice;
  }

  /// A non-cash tender cannot be reconciled without a reference, and
  /// `record_payment` refuses one.
  bool get requiresReference =>
      paymentMethod.value != PaymentMethod.cash &&
      paymentMethod.value != PaymentMethod.mixed;

  @override
  void onInit() {
    super.onInit();
    final InvoiceModel? preset = presetInvoice;
    if (preset != null) {
      invoiceId.value = preset.id;
      amountController.text = preset.outstandingAmount.toStringAsFixed(2);
    }
    unawaited(loadOpenInvoices());
  }

  Future<void> loadOpenInvoices() async {
    final String? id = showroomId;
    isLoadingInvoices.value = true;
    try {
      final PaginatedResponse<InvoiceModel> page = await invoiceRepository.list(
        QueryParams(
          pageSize: 100,
          showroomId: id,
          filters: <QueryFilter>[
            const QueryFilter.greaterOrEqual('outstanding_amount', 0.01),
          ],
          sorts: <QuerySort>[const QuerySort(column: 'invoice_date')],
        ),
      );
      openInvoices.assignAll(page.items);
    } on Object catch (e) {
      AppSnackbar.fromException(e);
    } finally {
      isLoadingInvoices.value = false;
    }
  }

  void selectInvoice(String? id) {
    invoiceId.value = id;
    final InvoiceModel? invoice = selectedInvoice;
    if (invoice != null) {
      // Default to settling the balance in full, which is the common case.
      amountController.text = invoice.outstandingAmount.toStringAsFixed(2);
    }
  }

  String? validateAmount(String? value) {
    final String? base = AppValidators.amount(value, field: 'Amount');
    if (base != null) {
      return base;
    }
    final double amount = double.tryParse((value ?? '').trim()) ?? 0;
    final InvoiceModel? invoice = selectedInvoice;
    if (invoice != null && amount > invoice.outstandingAmount + 0.01) {
      // The server refuses this too unless it is deliberately booked as an
      // advance, which this screen does not offer.
      return 'Exceeds the outstanding balance of '
          '${invoice.formattedOutstanding}.';
    }
    return null;
  }

  String? validateReference(String? value) =>
      AppValidators.paymentReference(value, isRequired: requiresReference);

  Future<String?> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return null;
    }
    if (invoiceId.value == null) {
      AppSnackbar.error('Select the invoice this payment settles.');
      return null;
    }

    final SessionController session = Get.find<SessionController>();
    if (!session.can(AppPermissions.paymentsCreate)) {
      AppSnackbar.error('You do not have permission to record a payment.');
      return null;
    }

    final String? id = selectedInvoice?.showroomId ?? showroomId;
    if (id == null) {
      AppSnackbar.error('Select a showroom first.');
      return null;
    }

    isSubmitting.value = true;
    try {
      final String paymentId = await paymentRepository
          .recordPayment(<String, Object?>{
            'showroom_id': id,
            'invoice_id': invoiceId.value,
            'sale_id': selectedInvoice?.saleId,
            'customer_id': selectedInvoice?.customerId,
            'amount': double.tryParse(amountController.text.trim()) ?? 0,
            'payment_method': paymentMethod.value.value,
            'payment_date': DateUtil.toIsoDateOrNull(paymentDate.value),
            'allocation': PaymentAllocation.invoice.value,
            if (referenceController.text.trim().isNotEmpty)
              'reference_number': referenceController.text.trim(),
            if (notesController.text.trim().isNotEmpty)
              'notes': notesController.text.trim(),
          });
      AppSnackbar.success('Payment recorded.');
      return paymentId;
    } on Object catch (e) {
      AppSnackbar.fromException(e);
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    amountController.dispose();
    referenceController.dispose();
    notesController.dispose();
    super.onClose();
  }
}
