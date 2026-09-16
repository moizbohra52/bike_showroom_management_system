/// Sales, billing and payment enumerations.
library;

/// How a sale was transacted. Affects which downstream records are created by
/// `create_sale_transaction()`.
enum SaleType {
  cash('CASH', 'Cash Sale'),
  finance('FINANCE', 'Finance / EMI'),
  exchange('EXCHANGE', 'Exchange'),
  corporate('CORPORATE', 'Corporate'),
  institutional('INSTITUTIONAL', 'Institutional');

  const SaleType(this.value, this.label);

  final String value;
  final String label;

  static SaleType fromValue(String? value) => SaleType.values.firstWhere(
    (SaleType type) => type.value == value,
    orElse: () => SaleType.cash,
  );

  /// Finance sales must supply loan details so an EMI schedule can be built.
  bool get requiresLoan => this == SaleType.finance;
}

/// Status of a sale document.
enum SaleStatus {
  draft('DRAFT', 'Draft'),
  pendingApproval('PENDING_APPROVAL', 'Pending Approval'),
  confirmed('CONFIRMED', 'Confirmed'),
  delivered('DELIVERED', 'Delivered'),
  cancelled('CANCELLED', 'Cancelled');

  const SaleStatus(this.value, this.label);

  final String value;
  final String label;

  static SaleStatus fromValue(String? value) => SaleStatus.values.firstWhere(
    (SaleStatus status) => status.value == value,
    orElse: () => SaleStatus.draft,
  );

  /// A confirmed sale has produced accounting entries and an invoice, so it may
  /// only be reversed through a controlled cancellation.
  bool get isFinalised =>
      this == SaleStatus.confirmed || this == SaleStatus.delivered;

  bool get isEditable =>
      this == SaleStatus.draft || this == SaleStatus.pendingApproval;

  /// Whether the sale still contributes to revenue figures.
  bool get countsAsRevenue => isFinalised;
}

/// Kind of invoice document.
enum InvoiceType {
  sale('SALE', 'Sale Invoice'),
  service('SERVICE', 'Service Invoice'),
  accessory('ACCESSORY', 'Accessory Invoice'),
  other('OTHER', 'Other Invoice');

  const InvoiceType(this.value, this.label);

  final String value;
  final String label;

  static InvoiceType fromValue(String? value) => InvoiceType.values.firstWhere(
    (InvoiceType type) => type.value == value,
    orElse: () => InvoiceType.other,
  );
}

/// Status of an invoice. Finalised invoices are immutable; corrections happen
/// through cancellation or a credit note, never by editing in place.
enum InvoiceStatus {
  draft('DRAFT', 'Draft'),
  issued('ISSUED', 'Issued'),
  partiallyPaid('PARTIALLY_PAID', 'Partially Paid'),
  paid('PAID', 'Paid'),
  overdue('OVERDUE', 'Overdue'),
  cancelled('CANCELLED', 'Cancelled');

  const InvoiceStatus(this.value, this.label);

  final String value;
  final String label;

  static InvoiceStatus fromValue(String? value) =>
      InvoiceStatus.values.firstWhere(
        (InvoiceStatus status) => status.value == value,
        orElse: () => InvoiceStatus.draft,
      );

  /// Once issued, line items and totals can no longer change.
  bool get isImmutable => this != InvoiceStatus.draft;

  bool get isOutstanding =>
      this == InvoiceStatus.issued ||
      this == InvoiceStatus.partiallyPaid ||
      this == InvoiceStatus.overdue;

  bool get acceptsPayment => isOutstanding;
}

/// Tender type of a payment.
enum PaymentMethod {
  cash('CASH', 'Cash'),
  upi('UPI', 'UPI'),
  card('CARD', 'Card'),
  bankTransfer('BANK_TRANSFER', 'Bank Transfer'),
  cheque('CHEQUE', 'Cheque'),
  finance('FINANCE', 'Finance Disbursement'),
  online('ONLINE', 'Online Gateway'),
  mixed('MIXED', 'Mixed');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;

  static PaymentMethod fromValue(String? value) =>
      PaymentMethod.values.firstWhere(
        (PaymentMethod method) => method.value == value,
        orElse: () => PaymentMethod.cash,
      );

  /// Non-cash tenders need a traceable reference for reconciliation.
  bool get requiresReference =>
      this != PaymentMethod.cash && this != PaymentMethod.mixed;

  /// Which default account the credit/debit side posts to. Resolved against
  /// `accounts.account_code` seeded by `013_accounting.sql`.
  String get defaultAccountCode {
    switch (this) {
      case PaymentMethod.cash:
        return '1001';
      case PaymentMethod.upi:
      case PaymentMethod.card:
      case PaymentMethod.bankTransfer:
      case PaymentMethod.cheque:
      case PaymentMethod.online:
      case PaymentMethod.finance:
      case PaymentMethod.mixed:
        return '1002';
    }
  }
}

/// Direction of a payment record.
enum PaymentDirection {
  inbound('INBOUND', 'Received'),
  outbound('OUTBOUND', 'Paid Out');

  const PaymentDirection(this.value, this.label);

  final String value;
  final String label;

  static PaymentDirection fromValue(String? value) =>
      PaymentDirection.values.firstWhere(
        (PaymentDirection direction) => direction.value == value,
        orElse: () => PaymentDirection.inbound,
      );
}

/// Status of a payment. Financial rows are never physically deleted, so
/// reversal states exist instead.
enum PaymentStatus {
  pending('PENDING', 'Pending'),
  completed('COMPLETED', 'Completed'),
  failed('FAILED', 'Failed'),
  cancelled('CANCELLED', 'Cancelled'),
  reversed('REVERSED', 'Reversed'),
  refunded('REFUNDED', 'Refunded');

  const PaymentStatus(this.value, this.label);

  final String value;
  final String label;

  static PaymentStatus fromValue(String? value) =>
      PaymentStatus.values.firstWhere(
        (PaymentStatus status) => status.value == value,
        orElse: () => PaymentStatus.pending,
      );

  /// Only completed payments reduce customer outstanding.
  bool get reducesOutstanding => this == PaymentStatus.completed;

  bool get isReversal =>
      this == PaymentStatus.reversed || this == PaymentStatus.refunded;
}

/// Allocation target of a payment, used to decide which balance it settles.
enum PaymentAllocation {
  invoice('INVOICE', 'Against Invoice'),
  sale('SALE', 'Against Sale'),
  service('SERVICE', 'Against Service'),
  emi('EMI', 'Against EMI'),
  advance('ADVANCE', 'Customer Advance'),
  purchase('PURCHASE', 'Against Purchase'),
  expense('EXPENSE', 'Against Expense');

  const PaymentAllocation(this.value, this.label);

  final String value;
  final String label;

  static PaymentAllocation fromValue(String? value) =>
      PaymentAllocation.values.firstWhere(
        (PaymentAllocation allocation) => allocation.value == value,
        orElse: () => PaymentAllocation.advance,
      );
}
