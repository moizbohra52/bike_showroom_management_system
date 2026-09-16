/// Finance, EMI, purchase, expense and accounting enumerations.
library;

/// How loan interest is computed. The EMI formula used by
/// `calculate_emi()` differs per type, so this is a business-critical value.
enum InterestType {
  reducing('REDUCING', 'Reducing Balance'),
  flat('FLAT', 'Flat Rate');

  const InterestType(this.value, this.label);

  final String value;
  final String label;

  static InterestType fromValue(String? value) =>
      InterestType.values.firstWhere(
        (InterestType type) => type.value == value,
        orElse: () => InterestType.reducing,
      );
}

/// Status of a vehicle loan.
enum LoanStatus {
  pending('PENDING', 'Pending Approval'),
  active('ACTIVE', 'Active'),
  closed('CLOSED', 'Closed'),
  foreclosed('FORECLOSED', 'Foreclosed'),
  defaulted('DEFAULTED', 'Defaulted'),
  cancelled('CANCELLED', 'Cancelled');

  const LoanStatus(this.value, this.label);

  final String value;
  final String label;

  static LoanStatus fromValue(String? value) => LoanStatus.values.firstWhere(
    (LoanStatus status) => status.value == value,
    orElse: () => LoanStatus.pending,
  );

  /// Only an active loan accrues collectable EMI instalments.
  bool get isCollectable => this == LoanStatus.active;

  bool get isClosed =>
      this == LoanStatus.closed || this == LoanStatus.foreclosed;
}

/// Status of a single EMI instalment.
///
/// `UPCOMING` -> `DUE` -> `OVERDUE` progression is recomputed by the scheduled
/// function `refresh_emi_statuses()`, never trusted from the client.
enum EmiStatus {
  upcoming('UPCOMING', 'Upcoming'),
  due('DUE', 'Due'),
  partial('PARTIAL', 'Partially Paid'),
  paid('PAID', 'Paid'),
  overdue('OVERDUE', 'Overdue'),
  cancelled('CANCELLED', 'Cancelled');

  const EmiStatus(this.value, this.label);

  final String value;
  final String label;

  static EmiStatus fromValue(String? value) => EmiStatus.values.firstWhere(
    (EmiStatus status) => status.value == value,
    orElse: () => EmiStatus.upcoming,
  );

  /// Instalments that still owe money.
  bool get isOutstanding =>
      this == EmiStatus.upcoming ||
      this == EmiStatus.due ||
      this == EmiStatus.partial ||
      this == EmiStatus.overdue;

  /// Instalments that attract a late-payment penalty.
  bool get attractsPenalty => this == EmiStatus.overdue;

  bool get acceptsPayment => isOutstanding;
}

/// Status of a supplier purchase document.
enum PurchaseStatus {
  draft('DRAFT', 'Draft'),
  ordered('ORDERED', 'Ordered'),
  received('RECEIVED', 'Received'),
  partiallyReceived('PARTIALLY_RECEIVED', 'Partially Received'),
  cancelled('CANCELLED', 'Cancelled');

  const PurchaseStatus(this.value, this.label);

  final String value;
  final String label;

  static PurchaseStatus fromValue(String? value) =>
      PurchaseStatus.values.firstWhere(
        (PurchaseStatus status) => status.value == value,
        orElse: () => PurchaseStatus.draft,
      );

  /// Receiving a purchase is what creates inventory rows, so only these states
  /// have generated stock.
  bool get hasGeneratedStock =>
      this == PurchaseStatus.received ||
      this == PurchaseStatus.partiallyReceived;

  bool get isEditable => this == PurchaseStatus.draft;
}

/// Approval and settlement state of an expense voucher.
enum ExpenseStatus {
  draft('DRAFT', 'Draft'),
  pending('PENDING', 'Pending Approval'),
  approved('APPROVED', 'Approved'),
  rejected('REJECTED', 'Rejected'),
  paid('PAID', 'Paid'),
  cancelled('CANCELLED', 'Cancelled');

  const ExpenseStatus(this.value, this.label);

  final String value;
  final String label;

  static ExpenseStatus fromValue(String? value) =>
      ExpenseStatus.values.firstWhere(
        (ExpenseStatus status) => status.value == value,
        orElse: () => ExpenseStatus.draft,
      );

  /// An expense only posts to the ledger once approved.
  bool get isPosted =>
      this == ExpenseStatus.approved || this == ExpenseStatus.paid;

  bool get isEditable =>
      this == ExpenseStatus.draft || this == ExpenseStatus.pending;

  bool get awaitsDecision => this == ExpenseStatus.pending;
}

/// The five roots of the chart of accounts.
enum AccountType {
  asset('ASSET', 'Asset'),
  liability('LIABILITY', 'Liability'),
  equity('EQUITY', 'Equity'),
  income('INCOME', 'Income'),
  expense('EXPENSE', 'Expense');

  const AccountType(this.value, this.label);

  final String value;
  final String label;

  static AccountType fromValue(String? value) => AccountType.values.firstWhere(
    (AccountType type) => type.value == value,
    orElse: () => AccountType.asset,
  );

  /// Assets and expenses increase with a debit; the rest increase with a
  /// credit. Used to present balances with the correct sign.
  bool get isDebitNormal =>
      this == AccountType.asset || this == AccountType.expense;

  /// Income and expense accounts close into equity at period end; balance
  /// sheet accounts carry forward.
  bool get isProfitAndLossAccount =>
      this == AccountType.income || this == AccountType.expense;
}

/// What business event produced an accounting transaction. Kept in
/// `accounting_transactions.reference_type` so the ledger is always traceable
/// back to its source document.
enum AccountingReferenceType {
  sale('SALE', 'Sale'),
  invoice('INVOICE', 'Invoice'),
  payment('PAYMENT', 'Payment'),
  purchase('PURCHASE', 'Purchase'),
  expense('EXPENSE', 'Expense'),
  service('SERVICE', 'Service'),
  emi('EMI', 'EMI Collection'),
  loan('LOAN', 'Loan Disbursement'),
  stockAdjustment('STOCK_ADJUSTMENT', 'Stock Adjustment'),
  refund('REFUND', 'Refund'),
  openingBalance('OPENING_BALANCE', 'Opening Balance'),
  manual('MANUAL', 'Manual Journal');

  const AccountingReferenceType(this.value, this.label);

  final String value;
  final String label;

  static AccountingReferenceType fromValue(String? value) =>
      AccountingReferenceType.values.firstWhere(
        (AccountingReferenceType type) => type.value == value,
        orElse: () => AccountingReferenceType.manual,
      );
}
