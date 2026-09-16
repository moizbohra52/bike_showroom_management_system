import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// A payment (`payments`).
///
/// Recorded through `record_payment`, which validates the tender, refuses an
/// overpayment unless it is deliberately booked as an advance, updates the
/// invoice and sale balances and posts the accounting entries — all in one
/// transaction. Reversal goes through `reverse_payment`, which writes a
/// *contra* row rather than deleting this one: a payment that has been
/// receipted cannot be made to have never existed (§42).
class PaymentModel implements SyncableModel {
  const PaymentModel({
    required this.id,
    required this.showroomId,
    required this.paymentNumber,
    required this.paymentDate,
    required this.amount,
    this.customerId,
    this.invoiceId,
    this.saleId,
    this.serviceId,
    this.emiId,
    this.purchaseId,
    this.expenseId,
    this.customerName,
    this.invoiceNumber,
    this.receivedByName,
    this.paymentMethod = PaymentMethod.cash,
    this.direction = PaymentDirection.inbound,
    this.allocation = PaymentAllocation.invoice,
    this.referenceNumber,
    this.transactionId,
    this.status = PaymentStatus.completed,
    this.notes,
    this.reversedAt,
    this.reversesPaymentId,
    this.reversalReason,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader customer = JsonReader(
      reader.objectOrNull('customers') ?? const <String, Object?>{},
    );
    final JsonReader invoice = JsonReader(
      reader.objectOrNull('invoices') ?? const <String, Object?>{},
    );
    final JsonReader receivedBy = JsonReader(
      reader.objectOrNull('users') ?? const <String, Object?>{},
    );

    return PaymentModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      paymentNumber: reader.string('payment_number'),
      paymentDate: reader.dateOrNull('payment_date') ?? DateTime.now(),
      amount: reader.money('amount'),
      customerId: reader.stringOrNull('customer_id'),
      invoiceId: reader.stringOrNull('invoice_id'),
      saleId: reader.stringOrNull('sale_id'),
      serviceId: reader.stringOrNull('service_id'),
      emiId: reader.stringOrNull('emi_id'),
      purchaseId: reader.stringOrNull('purchase_id'),
      expenseId: reader.stringOrNull('expense_id'),
      customerName: customer.stringOrNull('name'),
      invoiceNumber: invoice.stringOrNull('invoice_number'),
      receivedByName: receivedBy.stringOrNull('name'),
      paymentMethod: PaymentMethod.fromValue(
        reader.stringOrNull('payment_method'),
      ),
      direction: PaymentDirection.fromValue(reader.stringOrNull('direction')),
      allocation: PaymentAllocation.fromValue(
        reader.stringOrNull('allocation'),
      ),
      referenceNumber: reader.stringOrNull('reference_number'),
      transactionId: reader.stringOrNull('transaction_id'),
      status: PaymentStatus.fromValue(reader.stringOrNull('status')),
      notes: reader.stringOrNull('notes'),
      reversedAt: reader.timestampOrNull('reversed_at'),
      reversesPaymentId: reader.stringOrNull('reverses_payment_id'),
      reversalReason: reader.stringOrNull('reversal_reason'),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;

  /// Receipt number from `next_document_number(..., 'PAYMENT')`.
  final String paymentNumber;

  final DateTime paymentDate;
  final double amount;

  final String? customerId;
  final String? invoiceId;
  final String? saleId;
  final String? serviceId;
  final String? emiId;
  final String? purchaseId;
  final String? expenseId;

  // Denormalised from embedded relations.
  final String? customerName;
  final String? invoiceNumber;
  final String? receivedByName;

  final PaymentMethod paymentMethod;
  final PaymentDirection direction;
  final PaymentAllocation allocation;

  /// Cheque number, UPI reference, card approval code. Mandatory for any
  /// non-cash tender — `record_payment` refuses one without it, because an
  /// unreferenced electronic payment cannot be reconciled against a bank
  /// statement.
  final String? referenceNumber;

  final String? transactionId;
  final PaymentStatus status;
  final String? notes;

  final DateTime? reversedAt;

  /// Set on the contra row that reverses an earlier payment.
  final String? reversesPaymentId;

  final String? reversalReason;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isReversed => status == PaymentStatus.reversed || reversedAt != null;

  /// Whether this row *is* a reversal of another payment.
  bool get isReversal => reversesPaymentId != null;

  bool get isInbound => direction == PaymentDirection.inbound;

  /// A completed, inbound, not-yet-reversed payment is the only kind that can
  /// be reversed.
  bool get canReverse =>
      status == PaymentStatus.completed && !isReversed && !isReversal;

  /// Non-cash tenders need a reference to be reconcilable.
  bool get requiresReference =>
      paymentMethod != PaymentMethod.cash &&
      paymentMethod != PaymentMethod.mixed;

  String get formattedAmount => MoneyUtil.format(amount);

  String get formattedDate => DateUtil.format(paymentDate);

  /// What the receipt was against, in words.
  String get allocationLabel => allocation.label;

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    // A recorded payment is a receipt. Only the note is editable; the amount,
    // the tender and the allocation are what the customer was given a receipt
    // for, and correcting one means reversing and re-recording.
    'notes': notes,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'showroom_id': showroomId,
    'payment_number': paymentNumber,
    'payment_date': DateUtil.toIsoDateOrNull(paymentDate),
    'amount': amount,
    'payment_method': paymentMethod.value,
    'direction': direction.value,
    'allocation': allocation.value,
    'status': status.value,
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is PaymentModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Payment($paymentNumber $formattedAmount)';
}
