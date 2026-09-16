import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// One instalment of a loan's repayment schedule (`emi_schedules`).
///
/// Written in full when the loan is created, then only ever updated by
/// payments and by the nightly `refresh_emi_statuses` job. Due dates are
/// month-end clamped server-side, so a loan starting on the 31st does not
/// skip February.
class EmiScheduleModel implements SyncableModel {
  const EmiScheduleModel({
    required this.id,
    required this.loanId,
    required this.emiNumber,
    required this.dueDate,
    this.loanNumber,
    this.customerName,
    this.customerPhone,
    this.principalAmount = 0,
    this.interestAmount = 0,
    this.emiAmount = 0,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.penaltyAmount = 0,
    this.paidDate,
    this.status = EmiStatus.upcoming,
    this.notes,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory EmiScheduleModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader loan = JsonReader(
      reader.objectOrNull('loans') ?? const <String, Object?>{},
    );
    final JsonReader customer = JsonReader(
      loan.objectOrNull('customers') ?? const <String, Object?>{},
    );

    return EmiScheduleModel(
      id: reader.requireString('id'),
      loanId: reader.string('loan_id'),
      emiNumber: reader.integer('emi_number'),
      dueDate: reader.dateOrNull('due_date') ?? DateTime.now(),
      loanNumber: loan.stringOrNull('loan_number'),
      customerName: customer.stringOrNull('name'),
      customerPhone: customer.stringOrNull('phone'),
      principalAmount: reader.money('principal_amount'),
      interestAmount: reader.money('interest_amount'),
      emiAmount: reader.money('emi_amount'),
      paidAmount: reader.money('paid_amount'),
      remainingAmount: reader.money('remaining_amount'),
      penaltyAmount: reader.money('penalty_amount'),
      paidDate: reader.dateOrNull('paid_date'),
      status: EmiStatus.fromValue(reader.stringOrNull('status')),
      notes: reader.stringOrNull('notes'),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String loanId;

  /// 1-based position in the schedule.
  final int emiNumber;

  final DateTime dueDate;

  // Denormalised from embedded relations, for the dashboard rows.
  final String? loanNumber;
  final String? customerName;
  final String? customerPhone;

  final double principalAmount;
  final double interestAmount;
  final double emiAmount;
  final double paidAmount;
  final double remainingAmount;

  /// Late fee accrued on this instalment.
  final double penaltyAmount;

  final DateTime? paidDate;
  final EmiStatus status;
  final String? notes;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isPaid => status == EmiStatus.paid || remainingAmount <= 0.01;

  bool get isOverdue => !isPaid && DateUtil.isExpired(dueDate);

  /// Due inside the next two weeks — what the collections list works from.
  bool get isDueSoon =>
      !isPaid && !isOverdue && DateUtil.daysUntil(dueDate) <= 14;

  int get daysOverdue => isOverdue ? DateUtil.daysOverdue(dueDate) : 0;

  /// What the customer must actually hand over, penalty included.
  double get amountDue => remainingAmount + penaltyAmount;

  String get formattedEmi => MoneyUtil.format(emiAmount);

  String get formattedDue => MoneyUtil.format(amountDue);

  String get formattedPenalty => MoneyUtil.format(penaltyAmount);

  String get formattedDueDate => DateUtil.format(dueDate);

  String get label => 'EMI $emiNumber';

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    // Amounts and status move only through `record_payment` and the nightly
    // status refresh; a note is the one thing a collections clerk may add.
    'notes': notes,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'loan_id': loanId,
    'emi_number': emiNumber,
    'due_date': DateUtil.toIsoDateOrNull(dueDate),
    'emi_amount': emiAmount,
    'paid_amount': paidAmount,
    'remaining_amount': remainingAmount,
    'penalty_amount': penaltyAmount,
    'status': status.value,
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is EmiScheduleModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Emi($emiNumber due $formattedDueDate)';
}
