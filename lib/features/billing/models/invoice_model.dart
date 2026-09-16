import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_item_model.dart';

/// A tax invoice (`invoices`).
///
/// Raised by `create_sale_transaction` (and, later, by the service
/// equivalent), never by the client. Once issued it is immutable: the
/// `guard_invoice_immutability` trigger refuses edits, and `payments` move
/// `paid_amount` and `outstanding_amount` rather than anyone setting them.
///
/// The client's job here is to display and print it.
class InvoiceModel implements SyncableModel {
  const InvoiceModel({
    required this.id,
    required this.showroomId,
    required this.customerId,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.saleId,
    this.serviceId,
    this.customerName,
    this.customerPhone,
    this.customerGstNumber,
    this.customerAddress,
    this.saleNumber,
    this.invoiceType = InvoiceType.sale,
    this.dueDate,
    this.subtotal = 0,
    this.discount = 0,
    this.taxAmount = 0,
    this.otherCharges = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.outstandingAmount = 0,
    this.status = InvoiceStatus.draft,
    this.pdfUrl,
    this.notes,
    this.cancelledAt,
    this.items = const <InvoiceItemModel>[],
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory InvoiceModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader customer = JsonReader(
      reader.objectOrNull('customers') ?? const <String, Object?>{},
    );
    final JsonReader sale = JsonReader(
      reader.objectOrNull('sales') ?? const <String, Object?>{},
    );

    return InvoiceModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      customerId: reader.string('customer_id'),
      invoiceNumber: reader.string('invoice_number'),
      invoiceDate: reader.dateOrNull('invoice_date') ?? DateTime.now(),
      saleId: reader.stringOrNull('sale_id'),
      serviceId: reader.stringOrNull('service_id'),
      customerName: customer.stringOrNull('name'),
      customerPhone: customer.stringOrNull('phone'),
      customerGstNumber: customer.stringOrNull('gst_number'),
      customerAddress: customer.stringOrNull('address'),
      saleNumber: sale.stringOrNull('sale_number'),
      invoiceType: InvoiceType.fromValue(reader.stringOrNull('invoice_type')),
      dueDate: reader.dateOrNull('due_date'),
      subtotal: reader.money('subtotal'),
      discount: reader.money('discount'),
      taxAmount: reader.money('tax_amount'),
      otherCharges: reader.money('other_charges'),
      totalAmount: reader.money('total_amount'),
      paidAmount: reader.money('paid_amount'),
      outstandingAmount: reader.money('outstanding_amount'),
      status: InvoiceStatus.fromValue(reader.stringOrNull('status')),
      pdfUrl: reader.stringOrNull('pdf_url'),
      notes: reader.stringOrNull('notes'),
      cancelledAt: reader.timestampOrNull('cancelled_at'),
      items: reader.list('invoice_items', InvoiceItemModel.fromJson),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String customerId;

  /// Statutory number from `next_document_number(..., 'INVOICE')`. Gap-free by
  /// construction — the counter is a locked row, not a sequence, so a rolled
  /// back transaction does not burn a number.
  final String invoiceNumber;

  final DateTime invoiceDate;
  final String? saleId;
  final String? serviceId;

  // Denormalised from embedded relations, for the printed header.
  final String? customerName;
  final String? customerPhone;
  final String? customerGstNumber;
  final String? customerAddress;
  final String? saleNumber;

  final InvoiceType invoiceType;
  final DateTime? dueDate;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double otherCharges;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final InvoiceStatus status;
  final String? pdfUrl;
  final String? notes;
  final DateTime? cancelledAt;

  final List<InvoiceItemModel> items;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isCancelled => status == InvoiceStatus.cancelled;

  bool get isPaid => status == InvoiceStatus.paid || outstandingAmount <= 0.01;

  bool get acceptsPayment => !isCancelled && !isPaid;

  /// Past its due date with money still owing.
  bool get isOverdue =>
      !isPaid && !isCancelled && dueDate != null && DateUtil.isExpired(dueDate);

  /// The amount in words, which an Indian tax invoice prints beneath the
  /// total.
  String get totalInWords => MoneyUtil.toWords(totalAmount);

  String get formattedTotal => MoneyUtil.format(totalAmount);

  String get formattedPaid => MoneyUtil.format(paidAmount);

  String get formattedOutstanding => MoneyUtil.format(outstandingAmount);

  String get formattedDate => DateUtil.format(invoiceDate);

  /// The taxable value across all lines — the base a GST summary reports.
  double get taxableValue => subtotal - discount;

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    // Only what remains writable after issue. Amounts, status and the number
    // are server-owned, and the immutability trigger enforces that.
    'notes': notes,
    'pdf_url': pdfUrl,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'showroom_id': showroomId,
    'customer_id': customerId,
    'invoice_number': invoiceNumber,
    'invoice_date': DateUtil.toIsoDateOrNull(invoiceDate),
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'outstanding_amount': outstandingAmount,
    'status': status.value,
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is InvoiceModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Invoice($invoiceNumber $formattedTotal)';
}
