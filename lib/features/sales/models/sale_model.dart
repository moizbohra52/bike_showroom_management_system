import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_item_model.dart';

/// A sale (`sales`).
///
/// Created only through `create_sale_transaction`, never by an insert from
/// here. That one server-side function prices the lines from the catalogue,
/// allocates the stock, registers the customer's vehicle, raises the invoice,
/// posts the double-entry accounting and — for a financed sale — builds the
/// loan and its EMI schedule, all inside a single database transaction. Doing
/// any of that from the client would leave a half-finished sale behind the
/// first time a request failed midway.
///
/// The model is consequently read-mostly: the only mutation the client can
/// make is cancelling, which is itself an RPC.
class SaleModel implements SyncableModel {
  const SaleModel({
    required this.id,
    required this.showroomId,
    required this.customerId,
    required this.saleNumber,
    required this.saleDate,
    this.vehicleId,
    this.salespersonId,
    this.customerName,
    this.customerPhone,
    this.salespersonName,
    this.invoiceId,
    this.invoiceNumber,
    this.subtotal = 0,
    this.discount = 0,
    this.taxAmount = 0,
    this.otherCharges = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.outstandingAmount = 0,
    this.saleType = SaleType.cash,
    this.status = SaleStatus.draft,
    this.notes,
    this.cancelledAt,
    this.cancellationReason,
    this.items = const <SaleItemModel>[],
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory SaleModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader customer = JsonReader(
      reader.objectOrNull('customers') ?? const <String, Object?>{},
    );
    final JsonReader salesperson = JsonReader(
      reader.objectOrNull('users') ?? const <String, Object?>{},
    );

    // `invoices` is a to-many relation from the sale's side, so PostgREST
    // returns an array even though a sale raises exactly one invoice.
    final List<Map<String, Object?>> invoices = reader.objectList('invoices');
    final JsonReader invoice = JsonReader(
      invoices.isEmpty ? const <String, Object?>{} : invoices.first,
    );

    return SaleModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      customerId: reader.string('customer_id'),
      saleNumber: reader.string('sale_number'),
      saleDate: reader.dateOrNull('sale_date') ?? DateTime.now(),
      vehicleId: reader.stringOrNull('vehicle_id'),
      salespersonId: reader.stringOrNull('salesperson_id'),
      customerName: customer.stringOrNull('name'),
      customerPhone: customer.stringOrNull('phone'),
      salespersonName: salesperson.stringOrNull('name'),
      invoiceId: invoice.stringOrNull('id'),
      invoiceNumber: invoice.stringOrNull('invoice_number'),
      subtotal: reader.money('subtotal'),
      discount: reader.money('discount'),
      taxAmount: reader.money('tax_amount'),
      otherCharges: reader.money('other_charges'),
      totalAmount: reader.money('total_amount'),
      paidAmount: reader.money('paid_amount'),
      outstandingAmount: reader.money('outstanding_amount'),
      saleType: SaleType.fromValue(reader.stringOrNull('sale_type')),
      status: SaleStatus.fromValue(reader.stringOrNull('status')),
      notes: reader.stringOrNull('notes'),
      cancelledAt: reader.timestampOrNull('cancelled_at'),
      cancellationReason: reader.stringOrNull('cancellation_reason'),
      items: reader.list('sale_items', SaleItemModel.fromJson),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String customerId;

  /// Statutory document number from `next_document_number(..., 'SALE')`.
  final String saleNumber;

  final DateTime saleDate;

  /// The customer vehicle this sale registered, for a serialised unit.
  final String? vehicleId;

  final String? salespersonId;

  // Denormalised from embedded relations.
  final String? customerName;
  final String? customerPhone;
  final String? salespersonName;
  final String? invoiceId;
  final String? invoiceNumber;

  final double subtotal;
  final double discount;
  final double taxAmount;
  final double otherCharges;
  final double totalAmount;
  final double paidAmount;

  /// Maintained server-side as payments land. Never computed here: the client
  /// would disagree with the ledger the moment a payment was recorded from
  /// another device.
  final double outstandingAmount;

  final SaleType saleType;
  final SaleStatus status;
  final String? notes;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  final List<SaleItemModel> items;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isCancelled => status == SaleStatus.cancelled;

  bool get isFullyPaid => outstandingAmount <= 0.01;

  bool get isFinanced => saleType == SaleType.finance;

  /// Whether a payment can still be recorded against this sale.
  bool get acceptsPayment => !isCancelled && !isFullyPaid;

  /// Whether the sale may still be cancelled.
  ///
  /// Mirrors `cancel_sale_transaction`'s own guard so the button is hidden
  /// rather than offered and then refused; the server decides either way.
  bool get canCancel => !isCancelled;

  /// Total discount as a share of the pre-discount value — what the approval
  /// threshold in `create_sale_transaction` is measured against.
  double get discountPercentage =>
      subtotal <= 0 ? 0 : discount / subtotal * 100;

  String get formattedTotal => MoneyUtil.format(totalAmount);

  String get formattedPaid => MoneyUtil.format(paidAmount);

  String get formattedOutstanding => MoneyUtil.format(outstandingAmount);

  String get formattedDate => DateUtil.format(saleDate);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    // Only the fields a later edit may legitimately touch. Amounts, status
    // and the document number are server-owned.
    'notes': notes,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'showroom_id': showroomId,
    'customer_id': customerId,
    'sale_number': saleNumber,
    'sale_date': DateUtil.toIsoDateOrNull(saleDate),
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'outstanding_amount': outstandingAmount,
    'sale_type': saleType.value,
    'status': status.value,
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is SaleModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Sale($saleNumber $formattedTotal)';
}

/// What `create_sale_transaction` returns.
///
/// A sale creates six or seven rows across as many tables; the function
/// reports the identifiers of each so the client can navigate straight to the
/// invoice or the loan without re-querying for them.
class SaleTransactionResult {
  const SaleTransactionResult({
    required this.saleId,
    required this.saleNumber,
    this.invoiceId,
    this.invoiceNumber,
    this.vehicleId,
    this.loanId,
    this.paymentId,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.outstanding = 0,
  });

  factory SaleTransactionResult.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return SaleTransactionResult(
      saleId: reader.requireString('sale_id'),
      saleNumber: reader.string('sale_number'),
      invoiceId: reader.stringOrNull('invoice_id'),
      invoiceNumber: reader.stringOrNull('invoice_number'),
      vehicleId: reader.stringOrNull('vehicle_id'),
      loanId: reader.stringOrNull('loan_id'),
      paymentId: reader.stringOrNull('payment_id'),
      totalAmount: reader.money('total_amount'),
      paidAmount: reader.money('paid_amount'),
      outstanding: reader.money('outstanding'),
    );
  }

  final String saleId;
  final String saleNumber;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? vehicleId;
  final String? loanId;
  final String? paymentId;
  final double totalAmount;
  final double paidAmount;
  final double outstanding;

  @override
  String toString() => 'SaleTransactionResult($saleNumber)';
}
