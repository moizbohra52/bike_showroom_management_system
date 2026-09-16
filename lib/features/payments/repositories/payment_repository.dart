import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/features/payments/models/payment_model.dart';

/// Remote data source for `payments`.
///
/// Both writes are RPCs. A payment changes the invoice balance, the sale
/// balance and the ledger at once, so it cannot be an insert.
class PaymentRepository extends SupabaseRepository<PaymentModel> {
  PaymentRepository({super.client});

  @override
  String get table => DbTables.payments;

  @override
  String get defaultSortColumn => 'payment_date';

  /// No `is_deleted` column: a payment is reversed, never deleted (§42).
  @override
  String? get softDeleteColumn => null;

  /// `received_by` is named explicitly — `payments` references `users` three
  /// times (received_by, created_by, updated_by), so a bare `users(...)`
  /// embed is ambiguous and PostgREST refuses the request.
  @override
  String get defaultSelect =>
      '*, customers(id, name, phone), '
      'invoices(id, invoice_number), '
      'users!payments_received_by_fkey(id, name)';

  @override
  PaymentModel fromJson(Map<String, Object?> json) =>
      PaymentModel.fromJson(json);

  /// Records a payment through `record_payment`.
  ///
  /// [payload] keys: `showroom_id`, `amount`, and one of `invoice_id` /
  /// `sale_id` / `service_id` / `emi_id`; optionally `customer_id`,
  /// `payment_method`, `payment_date`, `allocation`, `reference_number`,
  /// `transaction_id`, `notes` and `allow_advance`.
  ///
  /// Returns the new payment's id.
  Future<String> recordPayment(Map<String, Object?> payload) async {
    final Object? result = await rpc('record_payment', <String, Object?>{
      'p_payload': payload,
    });
    final String? id = result?.toString();
    if (id == null || id.isEmpty) {
      throw ServerException(
        message: 'The payment was not recorded. Please try again.',
      );
    }
    return id;
  }

  /// Reverses a payment through `reverse_payment`.
  ///
  /// Writes a contra entry rather than removing the original: the customer
  /// holds a receipt for it, and the ledger must show both the receipt and
  /// its reversal.
  Future<void> reversePayment({
    required String paymentId,
    required String reason,
  }) => rpc('reverse_payment', <String, Object?>{
    'p_payment_id': paymentId,
    'p_reason': reason,
  });
}
