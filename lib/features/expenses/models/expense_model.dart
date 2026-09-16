import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// An overhead the showroom incurs (`expenses`).
///
/// Recorded by `create_expense_transaction`, which posts the double-entry
/// pair — debit the category's expense account, credit cash or a payable.
/// Approval goes through `approve_expense`, which enforces a rule worth
/// naming: **you cannot approve an expense you recorded yourself**. That is
/// separation of duties, and it is enforced server-side, not by hiding a
/// button.
class ExpenseModel implements SyncableModel {
  const ExpenseModel({
    required this.id,
    required this.showroomId,
    required this.categoryId,
    required this.expenseNumber,
    required this.expenseDate,
    required this.amount,
    this.categoryName,
    this.categoryAccountCode,
    this.approvedByName,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.description,
    this.attachmentUrl,
    this.vendorName,
    this.referenceNumber,
    this.status = ExpenseStatus.draft,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.createdBy,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader category = JsonReader(
      reader.objectOrNull('expense_categories') ?? const <String, Object?>{},
    );
    final JsonReader approver = JsonReader(
      reader.objectOrNull('users') ?? const <String, Object?>{},
    );

    return ExpenseModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      categoryId: reader.string('category_id'),
      expenseNumber: reader.string('expense_number'),
      expenseDate: reader.dateOrNull('expense_date') ?? DateTime.now(),
      amount: reader.money('amount'),
      categoryName: category.stringOrNull('name'),
      categoryAccountCode: category.stringOrNull('account_code'),
      approvedByName: approver.stringOrNull('name'),
      taxAmount: reader.money('tax_amount'),
      totalAmount: reader.money('total_amount'),
      paymentMethod: PaymentMethod.fromValue(
        reader.stringOrNull('payment_method'),
      ),
      description: reader.stringOrNull('description'),
      attachmentUrl: reader.stringOrNull('attachment_url'),
      vendorName: reader.stringOrNull('vendor_name'),
      referenceNumber: reader.stringOrNull('reference_number'),
      status: ExpenseStatus.fromValue(reader.stringOrNull('status')),
      approvedBy: reader.stringOrNull('approved_by'),
      approvedAt: reader.timestampOrNull('approved_at'),
      rejectionReason: reader.stringOrNull('rejection_reason'),
      createdBy: reader.stringOrNull('created_by'),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String categoryId;

  /// From `next_document_number(..., 'EXPENSE')`.
  final String expenseNumber;

  final DateTime expenseDate;

  /// Net of tax.
  final double amount;

  // Denormalised from embedded relations.
  final String? categoryName;
  final String? categoryAccountCode;
  final String? approvedByName;

  final double taxAmount;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final String? description;

  /// A receipt image in storage. Upload arrives with Phase 9; a URL already
  /// recorded renders here.
  final String? attachmentUrl;

  final String? vendorName;
  final String? referenceNumber;
  final ExpenseStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;

  /// Who recorded it — needed to enforce that they may not also approve it.
  final String? createdBy;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isPending => status == ExpenseStatus.pending;

  bool get isApproved => status == ExpenseStatus.approved;

  bool get isRejected => status == ExpenseStatus.rejected;

  /// Whether [userId] may act on this expense's approval.
  ///
  /// Mirrors `approve_expense`'s own guard exactly: only a pending expense can
  /// be decided, and not by the person who recorded it — **unless** they are a
  /// super admin, whom the function exempts. Matching the exemption matters:
  /// a stricter client would hide the button from the one account that is
  /// allowed to use it, which on a single-administrator installation makes
  /// approval look broken.
  bool canBeDecidedBy(String? userId, {bool isSuperAdmin = false}) {
    if (!isPending || userId == null) {
      return false;
    }
    return isSuperAdmin || createdBy != userId;
  }

  bool get requiresReference =>
      paymentMethod != PaymentMethod.cash &&
      paymentMethod != PaymentMethod.mixed;

  String get formattedTotal => MoneyUtil.format(totalAmount);

  String get formattedAmount => MoneyUtil.format(amount);

  String get formattedDate => DateUtil.format(expenseDate);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    // Status, approval and the document number move only through
    // `approve_expense`; amounts are fixed once the entries are posted.
    'description': description,
    'vendor_name': vendorName,
    'reference_number': referenceNumber,
    'attachment_url': attachmentUrl,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'showroom_id': showroomId,
    'category_id': categoryId,
    'expense_number': expenseNumber,
    'expense_date': DateUtil.toIsoDateOrNull(expenseDate),
    'amount': amount,
    'total_amount': totalAmount,
    'status': status.value,
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is ExpenseModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Expense($expenseNumber $formattedTotal)';
}
