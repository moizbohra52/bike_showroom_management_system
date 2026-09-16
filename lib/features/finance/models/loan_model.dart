import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// A finance agreement (`loans`).
///
/// Created by `create_loan_with_schedule`, which computes the EMI with
/// `calculate_emi` and writes the whole repayment schedule in the same
/// transaction. The schedule is generated once, at creation — not derived on
/// the fly — because each instalment is a row that payments and penalties
/// attach to, and recomputing it later would move due dates a customer has
/// already been told about.
class LoanModel implements SyncableModel {
  const LoanModel({
    required this.id,
    required this.showroomId,
    required this.customerId,
    required this.financeCompanyId,
    required this.loanNumber,
    required this.startDate,
    this.vehicleId,
    this.saleId,
    this.customerName,
    this.customerPhone,
    this.financeCompanyName,
    this.saleNumber,
    this.loanAmount = 0,
    this.downPayment = 0,
    this.interestRate = 0,
    this.interestType = InterestType.reducing,
    this.tenureMonths = 0,
    this.emiAmount = 0,
    this.processingFee = 0,
    this.endDate,
    this.status = LoanStatus.active,
    this.notes,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory LoanModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader customer = JsonReader(
      reader.objectOrNull('customers') ?? const <String, Object?>{},
    );
    final JsonReader company = JsonReader(
      reader.objectOrNull('finance_companies') ?? const <String, Object?>{},
    );
    final JsonReader sale = JsonReader(
      reader.objectOrNull('sales') ?? const <String, Object?>{},
    );

    return LoanModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      customerId: reader.string('customer_id'),
      financeCompanyId: reader.string('finance_company_id'),
      loanNumber: reader.string('loan_number'),
      startDate: reader.dateOrNull('start_date') ?? DateTime.now(),
      vehicleId: reader.stringOrNull('vehicle_id'),
      saleId: reader.stringOrNull('sale_id'),
      customerName: customer.stringOrNull('name'),
      customerPhone: customer.stringOrNull('phone'),
      financeCompanyName: company.stringOrNull('name'),
      saleNumber: sale.stringOrNull('sale_number'),
      loanAmount: reader.money('loan_amount'),
      downPayment: reader.money('down_payment'),
      interestRate: reader.money('interest_rate'),
      interestType: InterestType.fromValue(
        reader.stringOrNull('interest_type'),
      ),
      tenureMonths: reader.integer('tenure_months'),
      emiAmount: reader.money('emi_amount'),
      processingFee: reader.money('processing_fee'),
      endDate: reader.dateOrNull('end_date'),
      status: LoanStatus.fromValue(reader.stringOrNull('status')),
      notes: reader.stringOrNull('notes'),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String customerId;
  final String financeCompanyId;
  final String loanNumber;
  final DateTime startDate;
  final String? vehicleId;
  final String? saleId;

  // Denormalised from embedded relations.
  final String? customerName;
  final String? customerPhone;
  final String? financeCompanyName;
  final String? saleNumber;

  /// The principal actually financed — the sale value less the down payment,
  /// as computed server-side.
  final double loanAmount;

  final double downPayment;

  /// Annual rate, as a percentage.
  final double interestRate;

  final InterestType interestType;
  final int tenureMonths;
  final double emiAmount;
  final double processingFee;
  final DateTime? endDate;
  final LoanStatus status;
  final String? notes;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isActive => status == LoanStatus.active;

  /// What the customer repays across the whole tenure.
  double get totalRepayable => emiAmount * tenureMonths;

  /// The cost of the credit: everything repaid beyond the principal.
  ///
  /// Worth showing plainly — on a FLAT-rate agreement it is markedly higher
  /// than the nominal rate suggests, which is exactly the comparison a
  /// customer is entitled to make.
  double get totalInterest {
    final double interest = totalRepayable - loanAmount;
    return interest < 0 ? 0 : interest;
  }

  String get formattedEmi => MoneyUtil.format(emiAmount);

  String get formattedLoanAmount => MoneyUtil.format(loanAmount);

  String get formattedTotalInterest => MoneyUtil.format(totalInterest);

  String get tenureLabel => '$tenureMonths months';

  String get formattedStartDate => DateUtil.format(startDate);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    // The agreement's financial terms are fixed once the schedule exists;
    // changing the rate or tenure means a new agreement, not an edit.
    'notes': notes,
    'status': status.value,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'showroom_id': showroomId,
    'customer_id': customerId,
    'loan_number': loanNumber,
    'loan_amount': loanAmount,
    'emi_amount': emiAmount,
    'tenure_months': tenureMonths,
    'status': status.value,
    'start_date': DateUtil.toIsoDateOrNull(startDate),
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is LoanModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Loan($loanNumber $formattedEmi x $tenureMonths)';
}
