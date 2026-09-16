import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/features/finance/models/loan_model.dart';

/// Remote data source for `loans`.
class LoanRepository extends SupabaseRepository<LoanModel> {
  LoanRepository({super.client});

  @override
  String get table => DbTables.loans;

  @override
  String get defaultSortColumn => 'start_date';

  /// No `is_deleted` column: a finance agreement is closed, foreclosed or
  /// cancelled — never deleted (§42).
  @override
  String? get softDeleteColumn => null;

  @override
  String get defaultSelect =>
      '*, customers(id, name, phone), '
      'finance_companies(id, name, code), '
      'sales(id, sale_number)';

  @override
  LoanModel fromJson(Map<String, Object?> json) => LoanModel.fromJson(json);

  /// Creates a standalone loan through `create_loan_with_schedule`.
  ///
  /// A loan raised as part of a sale goes through `create_sale_transaction`
  /// instead, which calls this same function inside the sale's transaction.
  /// This entry point exists for finance arranged after the fact.
  ///
  /// [payload] keys: `showroom_id`, `customer_id`, `finance_company_id`,
  /// `loan_amount`, `interest_rate`, `tenure_months`; optionally
  /// `down_payment`, `interest_type`, `processing_fee`, `start_date`,
  /// `vehicle_id` and `sale_id`.
  Future<String> createLoan(Map<String, Object?> payload) async {
    final Object? result = await rpc(
      'create_loan_with_schedule',
      <String, Object?>{'p_payload': payload},
    );
    final String? id = result?.toString();
    if (id == null || id.isEmpty) {
      throw ServerException(
        message: 'The loan was not created. Please try again.',
      );
    }
    return id;
  }

  /// Asks the database for an EMI figure.
  ///
  /// Deliberately not reimplemented in Dart: this is the same function
  /// `create_loan_with_schedule` uses, so a quoted EMI cannot drift from the
  /// schedule that gets generated — which a parallel implementation would
  /// eventually do, especially for FLAT interest.
  Future<double> calculateEmi({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    required String interestType,
  }) async {
    final Object? result = await rpc('calculate_emi', <String, Object?>{
      'p_principal': principal,
      'p_annual_rate': annualRate,
      'p_tenure_months': tenureMonths,
      'p_interest_type': interestType,
    });
    return result is num ? result.toDouble() : 0;
  }
}
