import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_model.dart';

/// Remote data source for `expenses`.
class ExpenseRepository extends SupabaseRepository<ExpenseModel> {
  ExpenseRepository({super.client});

  @override
  String get table => DbTables.expenses;

  @override
  String get defaultSortColumn => 'expense_date';

  /// No `is_deleted` column: an expense is cancelled or rejected, never
  /// deleted (§42).
  @override
  String? get softDeleteColumn => null;

  /// The approver embed **must** name its foreign key — `expenses` points at
  /// `users` three times (approved_by, created_by, updated_by), so a bare
  /// `users(...)` is ambiguous and PostgREST rejects the whole request.
  @override
  String get defaultSelect =>
      '*, expense_categories(id, name, account_code), '
      'users!expenses_approved_by_fkey(id, name)';

  @override
  ExpenseModel fromJson(Map<String, Object?> json) =>
      ExpenseModel.fromJson(json);

  /// Records an expense through `create_expense_transaction`.
  ///
  /// [payload]: `showroom_id`, `category_id`, `amount`, and optionally
  /// `tax_amount`, `expense_date`, `payment_method`, `description`,
  /// `vendor_name`, `reference_number` and `attachment_url`.
  ///
  /// Returns the new expense's id. Not an insert: the function posts the
  /// double-entry pair against the category's account in the same
  /// transaction.
  Future<String> createExpense(Map<String, Object?> payload) async {
    final Object? result = await rpc(
      'create_expense_transaction',
      <String, Object?>{'p_payload': payload},
    );
    final String? id = result?.toString();
    if (id == null || id.isEmpty) {
      throw ServerException(
        message: 'The expense was not recorded. Please try again.',
      );
    }
    return id;
  }

  /// Approves or rejects an expense through `approve_expense`.
  ///
  /// The function refuses a decision by whoever recorded the expense — that
  /// separation of duties is the whole point of the approval step, so it lives
  /// server-side rather than in a hidden button.
  Future<void> decide({
    required String expenseId,
    required bool approve,
    String? reason,
  }) => rpc('approve_expense', <String, Object?>{
    'p_expense_id': expenseId,
    'p_approve': approve,
    'p_reason': reason,
  });
}
